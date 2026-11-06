#include "zed_keychain_bridge.h"

#include <libsecret/secret.h>

#include <cstring>

namespace {

constexpr char kChannelName[] = "com.johntsui.stroom/zed_keychain";

struct ProviderService {
  const char* service;
  const char* provider;
};

constexpr ProviderService kProviderServices[] = {
    {"zed-openai", "openai"},      {"ai.zed.openai", "openai"},
    {"zed.openai", "openai"},      {"Zed-OpenAI", "openai"},
    {"zed-anthropic", "anthropic"},{"ai.zed.anthropic", "anthropic"},
    {"zed.anthropic", "anthropic"},{"Zed-Anthropic", "anthropic"},
    {"zed-google", "google"},      {"ai.zed.google", "google"},
    {"zed.google", "google"},      {"Zed-Google", "google"},
    {"zed-mistral", "mistral"},    {"ai.zed.mistral", "mistral"},
    {"zed.mistral", "mistral"},    {"Zed-Mistral", "mistral"},
    {"zed-xai", "xai"},            {"ai.zed.xai", "xai"},
    {"zed.xai", "xai"},            {"Zed-xAI", "xai"},
};

static const SecretSchema kZedSchema = {
    "org.freedesktop.Secret.Generic",
    SECRET_SCHEMA_NONE,
    {{"service", SECRET_SCHEMA_ATTRIBUTE_STRING},
     {"account", SECRET_SCHEMA_ATTRIBUTE_STRING}},
};

const char* provider_for_service(const char* service) {
  if (service == nullptr) return nullptr;
  for (const auto& entry : kProviderServices) {
    if (std::strcmp(service, entry.service) == 0) return entry.provider;
  }
  return nullptr;
}

char* fingerprint(const char* service, const char* account,
                  const char* secret) {
  GChecksum* checksum = g_checksum_new(G_CHECKSUM_SHA256);
  g_checksum_update(checksum,
                    reinterpret_cast<const guchar*>(service),
                    std::strlen(service));
  g_checksum_update(checksum, reinterpret_cast<const guchar*>("|"), 1);
  g_checksum_update(checksum,
                    reinterpret_cast<const guchar*>(account),
                    std::strlen(account));
  g_checksum_update(checksum, reinterpret_cast<const guchar*>("|"), 1);
  g_checksum_update(checksum,
                    reinterpret_cast<const guchar*>(secret),
                    std::strlen(secret));
  const char* full_digest = g_checksum_get_string(checksum);
  char* short_digest = g_strndup(full_digest, 16);
  g_checksum_free(checksum);
  return short_digest;
}

FlValue* candidate_value(const char* provider, const char* service,
                         const char* account, const char* digest) {
  FlValue* candidate = fl_value_new_map();
  fl_value_set_string_take(candidate, "provider", fl_value_new_string(provider));
  fl_value_set_string_take(candidate, "service", fl_value_new_string(service));
  fl_value_set_string_take(candidate, "account", fl_value_new_string(account));
  fl_value_set_string_take(candidate, "fingerprint",
                           fl_value_new_string(digest));
  return candidate;
}

FlValue* discover_candidates(GError** error) {
  FlValue* candidates = fl_value_new_list();
  for (const auto& entry : kProviderServices) {
    GHashTable* attributes = g_hash_table_new(g_str_hash, g_str_equal);
    g_hash_table_insert(attributes, const_cast<char*>("service"),
                        const_cast<char*>(entry.service));
    GList* items = secret_service_search_sync(
        nullptr, &kZedSchema, attributes,
        static_cast<SecretSearchFlags>(SECRET_SEARCH_ALL | SECRET_SEARCH_UNLOCK |
                                       SECRET_SEARCH_LOAD_SECRETS),
        nullptr, error);
    g_hash_table_unref(attributes);
    if (error != nullptr && *error != nullptr) {
      g_list_free_full(items, g_object_unref);
      fl_value_unref(candidates);
      return nullptr;
    }

    for (GList* node = items; node != nullptr; node = node->next) {
      auto* item = SECRET_ITEM(node->data);
      GHashTable* item_attributes = secret_item_get_attributes(item);
      const char* account = item_attributes == nullptr
                                ? nullptr
                                : static_cast<const char*>(
                                      g_hash_table_lookup(item_attributes,
                                                          "account"));
      SecretValue* value = secret_item_get_secret(item);
      const char* secret = value == nullptr ? nullptr : secret_value_get_text(value);
      if (account != nullptr && account[0] != '\0' && secret != nullptr &&
          secret[0] != '\0') {
        char* digest = fingerprint(entry.service, account, secret);
        fl_value_append_take(
            candidates,
            candidate_value(entry.provider, entry.service, account, digest));
        g_free(digest);
      }
      if (value != nullptr) secret_value_unref(value);
      if (item_attributes != nullptr) g_hash_table_unref(item_attributes);
    }
    g_list_free_full(items, g_object_unref);
  }
  return candidates;
}

char* read_secret(const char* service, const char* account, GError** error) {
  if (provider_for_service(service) == nullptr || account == nullptr ||
      account[0] == '\0') {
    return nullptr;
  }
  return secret_password_lookup_sync(&kZedSchema, nullptr, error,
                                     "service", service,
                                     "account", account,
                                     nullptr);
}

void handle_method_call(FlMethodChannel*, FlMethodCall* method_call,
                        gpointer) {
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;
  g_autoptr(GError) error = nullptr;

  if (std::strcmp(method, "discover") == 0) {
    FlValue* result = discover_candidates(&error);
    if (error != nullptr) {
      if (result != nullptr) fl_value_unref(result);
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "keychain_unavailable", "Zed keychain is unavailable", nullptr));
    } else {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
      fl_value_unref(result);
    }
  } else if (std::strcmp(method, "readSecret") == 0) {
    FlValue* arguments = fl_method_call_get_args(method_call);
    const char* service = arguments == nullptr
                              ? nullptr
                              : fl_value_get_string(
                                    fl_value_lookup_string(arguments, "service"));
    const char* account = arguments == nullptr
                              ? nullptr
                              : fl_value_get_string(
                                    fl_value_lookup_string(arguments, "account"));
    char* secret = read_secret(service, account, &error);
    if (error != nullptr) {
      response = FL_METHOD_RESPONSE(fl_method_error_response_new(
          "keychain_unavailable", "Zed keychain is unavailable", nullptr));
    } else if (secret == nullptr) {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      FlValue* value = fl_value_new_string(secret);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(value));
      fl_value_unref(value);
      secret_password_free(secret);
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

}  // namespace

void zed_keychain_bridge_register(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ZedKeychainBridge");
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar), kChannelName,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, handle_method_call, nullptr,
                                            nullptr);
}
