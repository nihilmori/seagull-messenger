#include "mark_messages_read_handler.hpp"
#include "utils_handler.hpp"

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

MarkMessagesReadHandler::MarkMessagesReadHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string MarkMessagesReadHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& request_body = request.RequestBody();
  if (request_body.empty()) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Request body is required");
  }

  userver::formats::json::Value json;
  try {
    json = userver::formats::json::FromString(request_body);
  } catch (const std::exception& e) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Invalid JSON format");
  }

  int user_id = 0;
  try {
    user_id = json["user_id"].As<int>();
  } catch (const std::exception& e) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id is required and must be an integer");
  }

  if (user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id must be a positive integer");
  }

  int chat_id = -1;
  try {
    if (json.HasMember("chat_id")) {
      chat_id = json["chat_id"].As<int>();
    }
  } catch (const std::exception& e) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("chat_id must be an integer");
  }

  int message_id = -1;
  try {
    if (json.HasMember("message_id")) {
      message_id = json["message_id"].As<int>();
    }
  } catch (const std::exception& e) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("message_id must be an integer");
  }

  if (chat_id == -1 && message_id == -1) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Either chat_id or message_id must be provided");
  }

  if (message_id != -1) {
    const auto chat_result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT chat_id FROM seagull_schema.actions WHERE message_id = $1",
        message_id);

    if (chat_result.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      return utils_handler::MakeErrorJson("Message not found");
    }

    chat_id = chat_result[0]["chat_id"].As<int>();

    const auto participant_check = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT 1 FROM seagull_schema.chat_users WHERE chat_id = $1 AND user_id = $2",
        chat_id, user_id);

    if (participant_check.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kForbidden);
      return utils_handler::MakeErrorJson("User is not a participant of this chat");
    }

    pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kMaster,
        "UPDATE seagull_schema.chat_users "
        "SET last_read_message_id = GREATEST(COALESCE(last_read_message_id, 0), $1) "
        "WHERE chat_id = $2 AND user_id = $3",
        message_id, chat_id, user_id);

    pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kMaster,
        "UPDATE seagull_schema.messages m "
        "SET is_read = TRUE "
        "FROM seagull_schema.actions a "
        "WHERE a.message_id = m.message_id "
        "AND m.message_id = $1 "
        "AND m.is_read = FALSE "
        "AND a.sender_id != $2",
        message_id, user_id);

  } 
  else if (chat_id != -1) {
    if (chat_id < 0) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson("chat_id must be a non-negative integer");
    }

    const auto participant_check = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT 1 FROM seagull_schema.chat_users WHERE chat_id = $1 AND user_id = $2",
        chat_id, user_id);

    if (participant_check.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kForbidden);
      return utils_handler::MakeErrorJson("User is not a participant of this chat");
    }

    const auto max_msg_result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT MAX(m.message_id) as max_id "
        "FROM seagull_schema.actions a "
        "JOIN seagull_schema.messages m ON a.message_id = m.message_id "
        "WHERE a.chat_id = $1",
        chat_id);

    if (!max_msg_result.IsEmpty() && !max_msg_result[0]["max_id"].IsNull()) {
      int max_message_id = max_msg_result[0]["max_id"].As<int>();

      pg_cluster_->Execute(
          userver::storages::postgres::ClusterHostType::kMaster,
          "UPDATE seagull_schema.chat_users "
          "SET last_read_message_id = $1 "
          "WHERE chat_id = $2 AND user_id = $3",
          max_message_id, chat_id, user_id);

      auto update_result = pg_cluster_->Execute(
          userver::storages::postgres::ClusterHostType::kMaster,
          "UPDATE seagull_schema.messages m "
          "SET is_read = TRUE "
          "FROM seagull_schema.actions a "
          "WHERE a.message_id = m.message_id "
          "AND a.chat_id = $1 "
          "AND m.is_read = FALSE "
          "AND m.message_id <= $2 "
          "AND a.sender_id != $3",
          chat_id, max_message_id, user_id);

    }
  }

  userver::formats::json::ValueBuilder resp;
  resp["status"] = "success";
  resp["user_id"] = user_id;
  if (chat_id != -1) {
    resp["chat_id"] = chat_id;
  }
  if (message_id != -1) {
    resp["message_id"] = message_id;
  }

  response.SetStatus(userver::server::http::HttpStatus::kOk);
  return userver::formats::json::ToString(resp.ExtractValue());
}

} // namespace myservice
