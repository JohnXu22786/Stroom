#ifndef RUNNER_ZED_KEYCHAIN_BRIDGE_H_
#define RUNNER_ZED_KEYCHAIN_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
zed_keychain_bridge_register(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_ZED_KEYCHAIN_BRIDGE_H_
