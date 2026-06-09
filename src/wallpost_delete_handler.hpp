#pragma once

#include <userver/components/component.hpp>
#include <userver/server/handlers/http_handler_base.hpp>
#include <userver/storages/postgres/cluster.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

class WallPostDeleteHandler : public userver::server::handlers::HttpHandlerBase {
public:
    static constexpr std::string_view kName = "handler-wallpost-delete";

    WallPostDeleteHandler(const userver::components::ComponentConfig& config,
                          const userver::components::ComponentContext& component_context);

    std::string HandleRequestThrow(
        const userver::server::http::HttpRequest& request,
        userver::server::request::RequestContext& context) const override;

private:
    std::shared_ptr<userver::storages::postgres::Cluster> pg_cluster_;
};

}  // namespace myservice
