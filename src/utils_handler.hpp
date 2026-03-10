#pragma once

#include <cstddef>
#include <optional>
#include <string>
#include <string_view>

namespace myservice::utils_handler {

std::string MakeErrorJson(std::string_view message);

bool IsBlank(std::string_view value);

struct PasswordRequirements {
  size_t min_length = 8;
  size_t max_length = 32;
};

bool IsCorrectPassword(std::string_view password,
                       const PasswordRequirements& reqs = {});

std::optional<std::string> ValidatePassword(
    std::string_view password, const PasswordRequirements& reqs = {});

bool TryParseInt(std::string_view source, int& out_value);

std::string GenerateSalt(std::size_t length = 16);

}  // namespace myservice::utils_handler
