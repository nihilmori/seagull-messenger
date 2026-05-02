#include <search_messages_handler.hpp>
#include <utils_handler.hpp>

#include <string>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

SearchMessagesHandler::SearchMessagesHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string SearchMessagesHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& query = request.GetArg("query");
  if (query.empty()) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Search query is required");
  }

  if (query.length() < 2) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Search query must be at least 2 characters");
  }

  const auto& user_id_str = request.GetArg("user_id");
  int user_id = 0;
  if (!utils_handler::TryParseInt(user_id_str, user_id) || user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id must be a positive integer");
  }

  int chat_id = 0;
  const auto& chat_id_str = request.GetArg("chat_id");
  if (!chat_id_str.empty()) {
    if (!utils_handler::TryParseInt(chat_id_str, chat_id) || chat_id <= 0) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson("chat_id must be a positive integer");
    }
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

  if (!chat_id_str.empty()) {
    const auto participant_check = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT 1 FROM seagull_schema.chat_users WHERE "
        "chat_id = $1 AND user_id = $2",
        chat_id, user_id);

    if (participant_check.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kForbidden);
      return utils_handler::MakeErrorJson(
          "User is not a participant of this chat");
    }
  }

  try {
    std::string search_pattern = "%" + query + "%";

    auto result = [&]() {
      if (!chat_id_str.empty()) {
        return pg_cluster_->Execute(
            userver::storages::postgres::ClusterHostType::kSlave,
            "SELECT m.message_id, m.content, a.sender_id, a.chat_id, "
            "to_char(m.sent_at AT TIME ZONE 'Europe/Moscow', 'DD.MM.YYYY "
            "HH24:MI:SS') AS sent_at "
            "FROM seagull_schema.actions a JOIN seagull_schema.messages m ON "
            "a.message_id = m.message_id "
            "WHERE a.chat_id = $1 AND m.content ILIKE $2 "
            "ORDER BY m.message_id ASC LIMIT $3 OFFSET $4",
            chat_id, search_pattern, limit, offset);
      }

      return pg_cluster_->Execute(
          userver::storages::postgres::ClusterHostType::kSlave,
          "SELECT m.message_id, m.content, a.sender_id, a.chat_id, "
          "to_char(m.sent_at AT TIME ZONE 'Europe/Moscow', 'DD.MM.YYYY "
          "HH24:MI:SS') AS sent_at "
          "FROM seagull_schema.actions a JOIN seagull_schema.messages m ON "
          "a.message_id = m.message_id "
          "JOIN seagull_schema.chat_users cu ON cu.chat_id = a.chat_id "
          "WHERE cu.user_id = $1 AND m.content ILIKE $2 "
          "ORDER BY m.message_id ASC LIMIT $3 OFFSET $4",
          user_id, search_pattern, limit, offset);
    }();

    userver::formats::json::ValueBuilder messages(
        userver::formats::common::Type::kArray);
    for (const auto& row : result) {
      userver::formats::json::ValueBuilder msg;
      msg["message_id"] = row["message_id"].As<int>();
      msg["content"] = row["content"].As<std::string>();
      msg["sender_id"] = row["sender_id"].As<int>();
      msg["chat_id"] = row["chat_id"].As<int>();
      msg["sent_at"] = row["sent_at"].As<std::string>();
      messages.PushBack(std::move(msg));
    }

    userver::formats::json::ValueBuilder resp;
    resp["query"] = query;
    resp["user_id"] = user_id;
    if (!chat_id_str.empty()) {
      resp["chat_id"] = chat_id;
    }
    resp["count"] = messages.GetSize();
    resp["limit"] = limit;
    resp["offset"] = offset;
    resp["messages"] = std::move(messages);

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());

  } catch (const std::exception&) {
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Database error occurred");
  }
}

}  // namespace myservice
