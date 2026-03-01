#include <utils_handler.hpp>

#include <string>

#include <userver/formats/json.hpp>

namespace myservice::utils_handler {

std::string MakeErrorJson(std::string_view message) {
  userver::formats::json::ValueBuilder error;
  error["error"] = std::string(message);
  return userver::formats::json::ToString(error.ExtractValue());
}

bool IsBlank(std::string_view value) {
  return value.find_first_not_of(" \t\n\r") == std::string_view::npos;
}

bool TryParseInt(std::string_view source, int& out_value) {
  try {
    const std::string source_copy(source);
    std::size_t pos = 0;
    const int parsed = std::stoi(source_copy, &pos);
    if (pos != source_copy.size()) {
      return false;
    }
    out_value = parsed;
    return true;
  } catch (const std::exception&) {
    return false;
  }
}

}  // namespace myservice::utils_handler
