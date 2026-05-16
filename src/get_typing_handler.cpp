#include "get_typing_handler.hpp"
#include "utils_handler.hpp"

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

GetTypingHandler::GetTypingHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string GetTypingHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& chat_id_str = request.GetArg("chat_id");
  int chat_id = 0;
  if (!utils_handler::TryParseInt(chat_id_str, chat_id) || chat_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("chat_id must be a positive integer");
  }

  const auto& user_id_str = request.GetArg("user_id");
  int user_id = 0;
  if (!utils_handler::TryParseInt(user_id_str, user_id) || user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id must be a positive integer");
  }

  const auto participant_check =
      pg_cluster_->Execute(userver::storages::postgres::ClusterHostType::kSlave,
                           "SELECT 1 FROM seagull_schema.chat_users WHERE "
                           "chat_id = $1 AND user_id = $2",
                           chat_id, user_id);

  if (participant_check.IsEmpty()) {
    response.SetStatus(userver::server::http::HttpStatus::kForbidden);
    return utils_handler::MakeErrorJson(
        "User is not a participant of this chat");
  }

  const auto result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kSlave,
      "SELECT ts.user_id, u.name, ts.is_typing "
      "FROM seagull_schema.typing_status ts "
      "JOIN seagull_schema.users u ON ts.user_id = u.user_id "
      "WHERE ts.chat_id = $1 "
      "AND ts.user_id != $2 "
      "AND ts.is_typing = TRUE "
      "AND ts.updated_at > NOW() - INTERVAL '5 seconds'",
      chat_id, user_id);

  userver::formats::json::ValueBuilder typing_users(
      userver::formats::common::Type::kArray);

  for (const auto& row : result) {
    userver::formats::json::ValueBuilder user;
    user["user_id"] = row["user_id"].As<int>();
    user["name"] = row["name"].As<std::string>();
    typing_users.PushBack(std::move(user));
  }

  userver::formats::json::ValueBuilder resp;
  resp["chat_id"] = chat_id;
  resp["typing_users"] = std::move(typing_users);
  resp["count"] = result.Size();

  response.SetStatus(userver::server::http::HttpStatus::kOk);
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
