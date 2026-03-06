#include <get_chat_info_handler.hpp>
#include <utils_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

GetChatInfoHandler::GetChatInfoHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string GetChatInfoHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const int chat_id = request["chat_id"].As<int>(0);
  
  if (chat_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("chat_id must be a positive integer");
  }

  const int user_id = request["user_id"].As<int>(0);

  try {
    auto chat_result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT chat_id, name, type FROM seagull_schema.chats WHERE chat_id = $1",
        chat_id);

    if (chat_result.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      return utils_handler::MakeErrorJson("Chat not found");
    }

    const auto& chat_row = chat_result[0];
    int chat_type = chat_row["type"].As<int>();

    if (user_id > 0) {
      auto participant_check = pg_cluster_->Execute(
          userver::storages::postgres::ClusterHostType::kSlave,
          "SELECT user_id FROM seagull_schema.chat_users "
          "WHERE chat_id = $1 AND user_id = $2",
          chat_id, user_id);

      if (participant_check.IsEmpty()) {
        response.SetStatus(userver::server::http::HttpStatus::kForbidden);
        return utils_handler::MakeErrorJson("User is not a participant of this chat");
      }
    }

    auto participants_result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT u.user_id, u.name FROM seagull_schema.chat_users cu "
        "JOIN seagull_schema.users u ON u.user_id = cu.user_id "
        "WHERE cu.chat_id = $1 ORDER BY u.name",
        chat_id);

    userver::formats::json::ValueBuilder participants(
        userver::formats::common::Type::kArray);

    for (const auto& row : participants_result) {
      userver::formats::json::ValueBuilder participant;
      participant["user_id"] = row["user_id"].As<int>();
      participant["name"] = row["name"].As<std::string>();
      participants.PushBack(std::move(participant));
    }

    userver::formats::json::ValueBuilder resp;
    resp["chat_id"] = chat_id;
    resp["name"] = chat_row["name"].As<std::string>();
    resp["type_name"] = (chat_type == 0) ? "group" : "private";
    resp["participants"] = participants.ExtractValue();
    resp["participants_count"] = participants_result.Size();

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());

  } catch (const std::exception& e) {
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Database error occurred");
  }
}

}  // namespace myservice
