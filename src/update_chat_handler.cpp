#include "update_chat_handler.hpp"

#include <utils_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>
#include <userver/storages/postgres/transaction.hpp>

namespace myservice {

UpdateChatHandler::UpdateChatHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string UpdateChatHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& chat_id_arg = request.GetPathArg("chat_id");
  int chat_id = 0;
  if (!utils_handler::TryParseInt(chat_id_arg, chat_id) || chat_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("chat_id must be a positive integer");
  }

  userver::formats::json::Value body;
  try {
    body = userver::formats::json::FromString(request.RequestBody());
  } catch (const std::exception&) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Invalid JSON body");
  }

  const int user_id = body["user_id"].As<int>(0);
  const auto name = body["name"].As<std::string>("");

  if (user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Field 'user_id' must be a positive integer");
  }

  if (utils_handler::IsBlank(name)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'name' must not be empty");
  }

  auto transaction =
      pg_cluster_->Begin(userver::storages::postgres::ClusterHostType::kMaster,
                         userver::storages::postgres::TransactionOptions{});

  try {
    const auto chat_result = transaction.Execute(
        "SELECT type FROM seagull_schema.chats WHERE chat_id = $1", chat_id);
    if (chat_result.IsEmpty()) {
      transaction.Rollback();
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      return utils_handler::MakeErrorJson("Chat not found");
    }

    if (chat_result[0]["type"].As<int>() != 0) {
      transaction.Rollback();
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson("Only group chats can be renamed");
    }

    const auto participant_check = transaction.Execute(
        "SELECT 1 FROM seagull_schema.chat_users WHERE chat_id = $1 AND "
        "user_id = $2",
        chat_id, user_id);
    if (participant_check.IsEmpty()) {
      transaction.Rollback();
      response.SetStatus(userver::server::http::HttpStatus::kForbidden);
      return utils_handler::MakeErrorJson(
          "User is not a participant of this chat");
    }

    transaction.Execute(
        "UPDATE seagull_schema.chats SET name = $1 WHERE chat_id = $2", name,
        chat_id);

    transaction.Commit();

    userver::formats::json::ValueBuilder resp;
    resp["chat_id"] = chat_id;
    resp["name"] = name;

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());
  } catch (const std::exception&) {
    transaction.Rollback();
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Failed to update chat");
  }
}

}  // namespace myservice
