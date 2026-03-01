#pragma once

#include <string>
#include <string_view>

namespace myservice::utils_handler {

std::string MakeErrorJson(std::string_view message);

bool IsBlank(std::string_view value);

bool TryParseInt(std::string_view source, int& out_value);

}  // namespace myservice::utils_handler
