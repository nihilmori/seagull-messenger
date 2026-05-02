#include <delete_message_handler.hpp>
#include <utils_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

DeleteMessageHandler::DeleteMessageHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string DeleteMessageHandler::HandleRequestThrow(
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
  if (user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Field 'user_id' must be a positive integer");
  }

  try {
    const auto action_result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kMaster,
        "SELECT sender_id FROM seagull_schema.actions WHERE message_id = $1",
        message_id);

    if (action_result.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      return utils_handler::MakeErrorJson("Message not found");
    }

    const int sender_id = action_result[0]["sender_id"].As<int>();
    if (sender_id != user_id) {
      response.SetStatus(userver::server::http::HttpStatus::kForbidden);
      return utils_handler::MakeErrorJson(
          "User is not the sender of this message");
    }

    pg_cluster_->Execute(userver::storages::postgres::ClusterHostType::kMaster,
                         "DELETE FROM seagull_schema.messages "
                         "WHERE message_id = $1",
                         message_id);

    userver::formats::json::ValueBuilder resp;
    resp["message_id"] = message_id;
    resp["deleted"] = true;

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());
  } catch (const std::exception&) {
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Failed to delete message");
  }
}

}  // namespace myservice
