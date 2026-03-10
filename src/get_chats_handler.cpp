#include <get_chats_handler.hpp>
#include <utils_handler.hpp>

#include <utility>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

GetChatsHandler::GetChatsHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string GetChatsHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& user_id_str = request.GetArg("user_id");
  if (user_id_str.empty()) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id is required");
  }

  int user_id = 0;
  if (!utils_handler::TryParseInt(user_id_str, user_id) || user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id must be a positive integer");
  }

  constexpr int kDefaultLimit = 50;
  constexpr int kMaxLimit = 200;

  int limit = kDefaultLimit;
  const auto& limit_arg = request.GetArg("limit");
  if (!limit_arg.empty()) {
    if (!utils_handler::TryParseInt(limit_arg, limit) || limit <= 0 ||
        limit > kMaxLimit) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson(
          "limit must be an integer in range [1, " + std::to_string(kMaxLimit) +
          "]");
    }
  }

  int offset = 0;
  const auto& offset_arg = request.GetArg("offset");
  if (!offset_arg.empty()) {
    if (!utils_handler::TryParseInt(offset_arg, offset) || offset < 0) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson(
          "offset must be a non-negative integer");
    }
  }

  try {
    auto user_check = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT user_id FROM seagull_schema.users WHERE user_id = $1", user_id);

    if (user_check.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      return utils_handler::MakeErrorJson("User not found");
    }

    const auto result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT c.chat_id, c.name, "
        "to_char(MAX(m.sent_at) AT TIME ZONE 'Europe/Moscow', "
        "'DD.MM.YYYY HH24:MI:SS') AS last_message_at "
        "FROM seagull_schema.chats c "
        "JOIN seagull_schema.chat_users cu ON cu.chat_id = c.chat_id "
        "LEFT JOIN seagull_schema.actions a ON a.chat_id = c.chat_id "
        "LEFT JOIN seagull_schema.messages m ON m.message_id = a.message_id "
        "WHERE cu.user_id = $1 "
        "GROUP BY c.chat_id, c.name "
        "ORDER BY MAX(m.sent_at) DESC NULLS LAST, c.chat_id DESC "
        "LIMIT $2 OFFSET $3",
        user_id, limit, offset);

    userver::formats::json::ValueBuilder chats(
        userver::formats::common::Type::kArray);

    for (const auto& row : result) {
      userver::formats::json::ValueBuilder chat;
      chat["chat_id"] = row["chat_id"].As<int>();
      chat["name"] = row["name"].As<std::string>();
      chat["last_message_at"] = row["last_message_at"].As<std::string>();
      chats.PushBack(std::move(chat));
    }

    auto count_result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT COUNT(*) FROM seagull_schema.chat_users WHERE user_id = $1",
        user_id);

    int total_chats = count_result.AsSingleRow<int>();

    userver::formats::json::ValueBuilder resp;
    resp["user_id"] = user_id;
    resp["limit"] = limit;
    resp["offset"] = offset;
    resp["total"] = total_chats;
    resp["has_more"] = (offset + limit) < total_chats;
    resp["chats"] = std::move(chats);

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());

  } catch (const std::exception& e) {
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Database error occurred");
  }
}

}  // namespace myservice
