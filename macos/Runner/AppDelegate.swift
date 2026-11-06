import Cocoa
import CryptoKit
import FlutterMacOS
import Security

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Keep the app running in the background even when all windows
    // are closed. This ensures long-running background tasks
    // (API calls, TTS, etc.) are not interrupted.
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

/// Reads only Zed's known provider-key services. Secret values are returned to
/// Dart only for the selected item after UI confirmation; discovery exposes a
/// short, non-secret fingerprint instead.
enum ZedKeychainBridge {
  private static let channelName = "com.johntsui.stroom/zed_keychain"
  private static let providerByService: [String: String] = [
    "zed-openai": "openai",
    "ai.zed.openai": "openai",
    "zed.openai": "openai",
    "Zed-OpenAI": "openai",
    "zed-anthropic": "anthropic",
    "ai.zed.anthropic": "anthropic",
    "zed.anthropic": "anthropic",
    "Zed-Anthropic": "anthropic",
    "zed-google": "google",
    "ai.zed.google": "google",
    "zed.google": "google",
    "Zed-Google": "google",
    "zed-mistral": "mistral",
    "ai.zed.mistral": "mistral",
    "zed.mistral": "mistral",
    "Zed-Mistral": "mistral",
    "zed-xai": "xai",
    "ai.zed.xai": "xai",
    "zed.xai": "xai",
    "Zed-xAI": "xai",
  ]

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "discover":
          result(try discover())
        case "readSecret":
          guard
            let arguments = call.arguments as? [String: Any],
            let service = arguments["service"] as? String,
            let account = arguments["account"] as? String,
            providerByService[service] != nil
          else {
            result(FlutterError(code: "invalid_request", message: nil, details: nil))
            return
          }
          result(try readSecret(service: service, account: account))
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "keychain_unavailable", message: nil, details: nil))
      }
    }
  }

  private static func discover() throws -> [[String: String]] {
    var candidates: [[String: String]] = []
    for (service, provider) in providerByService {
      // Keep SecItem on macOS's default file-based login Keychain. Zed's
      // keytar-compatible generic-password entries use this store; its per-item
      // ACL can ask the user to allow another signed app to read a selected key.
      // Do not opt into the Data Protection Keychain, whose access groups are
      // restricted by the app's signing entitlements and aren't shared with Zed.
      var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecReturnAttributes as String: true,
        kSecMatchLimit as String: kSecMatchLimitAll,
      ]
      query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIAllow
      var rawItems: CFTypeRef?
      let status = SecItemCopyMatching(query as CFDictionary, &rawItems)
      if status == errSecItemNotFound { continue }
      guard status == errSecSuccess else { throw KeychainFailure.unavailable }

      let itemRecords: [[String: Any]]
      if let values = rawItems as? [[String: Any]] {
        itemRecords = values
      } else if let value = rawItems as? [String: Any] {
        itemRecords = [value]
      } else {
        continue
      }
      for item in itemRecords {
        guard let account = item[kSecAttrAccount as String] as? String,
              !account.isEmpty,
              let secret = try readSecret(service: service, account: account),
              !secret.isEmpty
        else { continue }
        candidates.append([
          "provider": provider,
          "service": service,
          "account": account,
          "fingerprint": fingerprint(service: service, account: account, secret: secret),
        ])
      }
    }
    return candidates
  }

  private static func readSecret(service: String, account: String) throws -> String? {
    guard providerByService[service] != nil else { throw KeychainFailure.unavailable }
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecUseAuthenticationUI as String: kSecUseAuthenticationUIAllow,
    ]
    var rawValue: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &rawValue)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess,
          let data = rawValue as? Data,
          let secret = String(data: data, encoding: .utf8)
    else { throw KeychainFailure.unavailable }
    return secret
  }

  private static func fingerprint(service: String, account: String, secret: String) -> String {
    let value = Data("\(service)|\(account)|\(secret)".utf8)
    return String(SHA256.hash(data: value).map { String(format: "%02x", $0) }.joined().prefix(16))
  }

  private enum KeychainFailure: Error {
    case unavailable
  }
}
