#include "edit_message_handler.hpp"

#include <utils_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>
#include <userver/storages/postgres/transaction.hpp>

namespace myservice {

EditMessageHandler::EditMessageHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string EditMessageHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& message_id_arg = request.GetPathArg("message_id");
  int message_id = 0;
  if (!utils_handler::TryParseInt(message_id_arg, message_id) ||
      message_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "message_id must be a positive integer");
  }

  userver::formats::json::Value body;
  try {
    body = userver::formats::json::FromString(request.RequestBody());
  } catch (const std::exception&) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Invalid JSON body");
  }

  const int user_id = body["user_id"].As<int>(0);
  const auto content = body["content"].As<std::string>("");

  if (user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Field 'user_id' must be a positive integer");
  }

  if (utils_handler::IsBlank(content)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'content' must not be empty");
  }

  auto transaction =
      pg_cluster_->Begin(userver::storages::postgres::ClusterHostType::kMaster,
                         userver::storages::postgres::TransactionOptions{});

  try {
    const auto action_result = transaction.Execute(
        "SELECT a.chat_id FROM seagull_schema.actions a "
        "WHERE a.message_id = $1 AND a.sender_id = $2",
        message_id, user_id);

    if (action_result.IsEmpty()) {
      transaction.Rollback();
      const auto msg_check = pg_cluster_->Execute(
          userver::storages::postgres::ClusterHostType::kSlave,
          "SELECT 1 FROM seagull_schema.actions WHERE message_id = $1",
          message_id);
      if (msg_check.IsEmpty()) {
        response.SetStatus(userver::server::http::HttpStatus::kNotFound);
        return utils_handler::MakeErrorJson("Message not found");
      }
      response.SetStatus(userver::server::http::HttpStatus::kForbidden);
      return utils_handler::MakeErrorJson(
          "User is not the sender of this message");
    }

    transaction.Execute(
        "UPDATE seagull_schema.messages SET content = $1 WHERE message_id = $2",
        content, message_id);

    transaction.Commit();

    userver::formats::json::ValueBuilder resp;
    resp["message_id"] = message_id;
    resp["content"] = content;

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());
  } catch (const std::exception&) {
    transaction.Rollback();
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Failed to edit message");
  }
}

}  // namespace myservice
