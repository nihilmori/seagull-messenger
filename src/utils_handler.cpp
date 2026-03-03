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

bool IsCorrectPassword(std::string_view password, const PasswordRequirements& reqs){
	return !ValidatePassword(password, reqs).has_value();
}

std::optional<std::string> ValidatePassword(std::string_view password, const PasswordRequirements& reqs){
	if (password.length() < reqs.min_length){
		return "Password must be at least " + std::to_string(reqs.min_length) + " characters";
	}
	if (password.length() > reqs.max_length){
		return "Password must be a maximum on " + std::to_string(reqs.max_length) + " characters";
	}
	bool has_upper = false;
	bool has_lower = false;
	bool has_digit = false;
	for (unsigned char c: password){
		if (std::isupper(c)) has_upper = true;
		else if (std::islower(c)) has_lower = true;
		else if (std::isdigit(c)) has_digit = true;
		else if (std::isspace(c)) {
			return "Password can't contain spaces";
		}
	}

	if (!has_upper) {
		return "Password must contain uppercase letter";
	}

	if (!has_lower) {
		return "Password must contain lowercase letter";
	}

	if (!has_digit) {
		return "Password must contain digit";
	}
	return std::nullopt;
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
