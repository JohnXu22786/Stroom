#include "zed_keychain_bridge.h"

#include <windows.h>
#include <wincred.h>
#include <bcrypt.h>

#include <optional>
#include <set>
#include <string>
#include <utility>
#include <vector>

namespace {

constexpr char kChannelName[] = "com.johntsui.stroom/zed_keychain";

struct ProviderService {
  const wchar_t* service;
  const char* provider;
};

constexpr ProviderService kProviderServices[] = {
    {L"zed-openai", "openai"}, {L"ai.zed.openai", "openai"},
    {L"zed.openai", "openai"}, {L"Zed-OpenAI", "openai"},
    {L"zed-anthropic", "anthropic"}, {L"ai.zed.anthropic", "anthropic"},
    {L"zed.anthropic", "anthropic"}, {L"Zed-Anthropic", "anthropic"},
    {L"zed-google", "google"}, {L"ai.zed.google", "google"},
    {L"zed.google", "google"}, {L"Zed-Google", "google"},
    {L"zed-mistral", "mistral"}, {L"ai.zed.mistral", "mistral"},
    {L"zed.mistral", "mistral"}, {L"Zed-Mistral", "mistral"},
    {L"zed-xai", "xai"}, {L"ai.zed.xai", "xai"},
    {L"zed.xai", "xai"}, {L"Zed-xAI", "xai"},
};

std::optional<std::string> wide_to_utf8(const wchar_t* value) {
  if (value == nullptr) return std::nullopt;
  const int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value,
                                        -1, nullptr, 0, nullptr, nullptr);
  if (count <= 0) return std::nullopt;
  std::string result(static_cast<size_t>(count), '\0');
  if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1,
                          result.data(), count, nullptr, nullptr) <= 0) {
    return std::nullopt;
  }
  result.resize(static_cast<size_t>(count - 1));
  return result;
}

std::optional<std::wstring> utf8_to_wide(const std::string& value) {
  const int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                        value.c_str(), -1, nullptr, 0);
  if (count <= 0) return std::nullopt;
  std::wstring result(static_cast<size_t>(count), L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.c_str(), -1,
                          result.data(), count) <= 0) {
    return std::nullopt;
  }
  result.resize(static_cast<size_t>(count - 1));
  return result;
}

std::optional<std::string> fingerprint(const std::wstring& service,
                                       const std::string& account,
                                       const std::string& secret) {
  auto service_utf8 = wide_to_utf8(service.c_str());
  if (!service_utf8.has_value()) return std::nullopt;
  std::string input = *service_utf8 + "|" + account + "|" + secret;
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  DWORD object_size = 0;
  DWORD property_size = 0;
  DWORD digest_size = 0;
  std::vector<UCHAR> object;
  std::vector<UCHAR> digest;
  std::optional<std::string> result;

  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM,
                                  nullptr, 0) != 0 ||
      BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH,
                        reinterpret_cast<PUCHAR>(&object_size),
                        sizeof(object_size), &property_size, 0) != 0 ||
      BCryptGetProperty(algorithm, BCRYPT_HASH_LENGTH,
                        reinterpret_cast<PUCHAR>(&digest_size),
                        sizeof(digest_size), &property_size, 0) != 0) {
    if (algorithm != nullptr) BCryptCloseAlgorithmProvider(algorithm, 0);
    SecureZeroMemory(input.data(), input.size());
    return std::nullopt;
  }
  object.resize(object_size);
  digest.resize(digest_size);
  if (BCryptCreateHash(algorithm, &hash, object.data(), object_size,
                       nullptr, 0, 0) == 0 &&
      BCryptHashData(hash,
                     reinterpret_cast<PUCHAR>(input.data()),
                     static_cast<ULONG>(input.size()), 0) == 0 &&
      BCryptFinishHash(hash, digest.data(), digest_size, 0) == 0) {
    static constexpr char kHex[] = "0123456789abcdef";
    std::string value;
    value.reserve(16);
    for (size_t index = 0; index < 8; ++index) {
      value.push_back(kHex[digest[index] >> 4]);
      value.push_back(kHex[digest[index] & 0x0f]);
    }
    result = std::move(value);
  }
  if (hash != nullptr) BCryptDestroyHash(hash);
  BCryptCloseAlgorithmProvider(algorithm, 0);
  SecureZeroMemory(input.data(), input.size());
  SecureZeroMemory(object.data(), object.size());
  SecureZeroMemory(digest.data(), digest.size());
  return result;
}

const ProviderService* provider_for_service(const std::wstring& service) {
  for (const auto& entry : kProviderServices) {
    if (service == entry.service) return &entry;
  }
  return nullptr;
}

std::optional<std::string> read_secret(const std::wstring& service,
                                       const std::wstring& account) {
  if (provider_for_service(service) == nullptr || account.empty()) {
    return std::nullopt;
  }
  const std::wstring target = service + L"/" + account;
  PCREDENTIALW credential = nullptr;
  if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
    return std::nullopt;
  }
  std::optional<std::string> secret;
  if (credential->CredentialBlob != nullptr &&
      credential->CredentialBlobSize > 0) {
    secret = std::string(
        reinterpret_cast<const char*>(credential->CredentialBlob),
        credential->CredentialBlobSize);
    SecureZeroMemory(credential->CredentialBlob,
                     credential->CredentialBlobSize);
  }
  if (credential != nullptr) CredFree(credential);
  return secret;
}

std::optional<flutter::EncodableList> discover_candidates() {
  flutter::EncodableList candidates;
  std::set<std::pair<std::wstring, std::wstring>> seen;
  for (const auto& entry : kProviderServices) {
    const std::wstring service(entry.service);
    const std::wstring filter = service + L"/*";
    DWORD count = 0;
    PCREDENTIALW* credentials = nullptr;
    if (!CredEnumerateW(filter.c_str(), 0, &count, &credentials)) {
      if (GetLastError() == ERROR_NOT_FOUND) continue;
      return std::nullopt;
    }

    const std::wstring prefix = service + L"/";
    bool fingerprint_failed = false;
    for (DWORD index = 0; index < count; ++index) {
      PCREDENTIALW credential = credentials[index];
      if (credential == nullptr || credential->TargetName == nullptr ||
          credential->UserName == nullptr ||
          credential->CredentialBlob == nullptr ||
          credential->CredentialBlobSize == 0 ||
          credential->Type != CRED_TYPE_GENERIC) {
        continue;
      }
      const std::wstring target(credential->TargetName);
      if (target.rfind(prefix, 0) != 0) continue;
      const std::wstring account_wide(credential->UserName);
      if (account_wide.empty() || target != prefix + account_wide ||
          !seen.emplace(service, account_wide).second) {
        continue;
      }
      auto account = wide_to_utf8(account_wide.c_str());
      auto service_utf8 = wide_to_utf8(service.c_str());
      if (!account.has_value() || !service_utf8.has_value()) continue;

      std::string secret(
          reinterpret_cast<const char*>(credential->CredentialBlob),
          credential->CredentialBlobSize);
      auto digest = fingerprint(service, *account, secret);
      SecureZeroMemory(secret.data(), secret.size());
      if (!digest.has_value()) {
        fingerprint_failed = true;
        break;
      }
      flutter::EncodableMap item;
      item[flutter::EncodableValue("provider")] =
          flutter::EncodableValue(entry.provider);
      item[flutter::EncodableValue("service")] =
          flutter::EncodableValue(*service_utf8);
      item[flutter::EncodableValue("account")] =
          flutter::EncodableValue(*account);
      item[flutter::EncodableValue("fingerprint")] =
          flutter::EncodableValue(*digest);
      candidates.emplace_back(std::move(item));
    }
    for (DWORD index = 0; index < count; ++index) {
      if (credentials[index] != nullptr &&
          credentials[index]->CredentialBlob != nullptr &&
          credentials[index]->CredentialBlobSize > 0) {
        SecureZeroMemory(credentials[index]->CredentialBlob,
                         credentials[index]->CredentialBlobSize);
      }
    }
    if (credentials != nullptr) CredFree(credentials);
    if (fingerprint_failed) return std::nullopt;
  }
  return candidates;
}

}  // namespace

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
zed_keychain_bridge_register(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<
      flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "discover") {
          auto candidates = discover_candidates();
          if (!candidates.has_value()) {
            result->Error("keychain_unavailable", "Zed keychain is unavailable");
          } else {
            result->Success(flutter::EncodableValue(std::move(*candidates)));
          }
          return;
        }
        if (call.method_name() == "readSecret") {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments == nullptr) {
            result->Error("invalid_request", "Invalid keychain request");
            return;
          }
          const auto service_it =
              arguments->find(flutter::EncodableValue("service"));
          const auto account_it =
              arguments->find(flutter::EncodableValue("account"));
          if (service_it == arguments->end() || account_it == arguments->end() ||
              !std::holds_alternative<std::string>(service_it->second) ||
              !std::holds_alternative<std::string>(account_it->second)) {
            result->Error("invalid_request", "Invalid keychain request");
            return;
          }
          auto service = utf8_to_wide(std::get<std::string>(service_it->second));
          auto account = utf8_to_wide(std::get<std::string>(account_it->second));
          if (!service.has_value() || !account.has_value()) {
            result->Error("invalid_request", "Invalid keychain request");
            return;
          }
          auto secret = read_secret(*service, *account);
          if (!secret.has_value()) {
            result->Success(flutter::EncodableValue());
          } else {
            result->Success(flutter::EncodableValue(*secret));
            SecureZeroMemory(secret->data(), secret->size());
          }
          return;
        }
        result->NotImplemented();
      });
  return channel;
}
