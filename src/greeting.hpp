#pragma once

#include <string>
#include <string_view>

namespace myservice {

enum class UserType { kFirstTime, kKnown };

std::string SayHelloTo(std::string_view name, UserType type);

}  // namespace myservice