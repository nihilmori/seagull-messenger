.pragma library

const ApiClient = (function() {
    let baseUrl = "http://127.0.0.1:8080";

    function normalizeBaseUrl(url) {
        if (typeof url !== "string") {
            return baseUrl;
        }
        const trimmed = url.trim();
        if (!trimmed) {
            return baseUrl;
        }
        return trimmed.endsWith("/") ? trimmed.slice(0, -1) : trimmed;
    }

    function normalizePath(path) {
        if (typeof path !== "string") {
            return "/";
        }
        const trimmed = path.trim();
        if (!trimmed) {
            return "/";
        }
        return trimmed.startsWith("/") ? trimmed : `/${trimmed}`;
    }

    function toQueryString(data) {
        if (!data) {
            return "";
        }

        const parts = [];
        const keys = Object.keys(data);
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            const value = data[key];
            if (value === undefined || value === null || value === "") {
                continue;
            }
            parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
        }
        return parts.length > 0 ? parts.join("&") : "";
    }

    function safeParseJson(text) {
        if (!text) {
            return {};
        }
        try {
            return JSON.parse(text);
        } catch (e) {
            return { error: "Failed to parse JSON response" };
        }
    }

    function sendRequest(method, path, data, callback) {
        const hasCallback = typeof callback === "function";
        const normalizedMethod = String(method || "GET").toUpperCase();
        const normalizedPath = normalizePath(path);

        const executor = function(resolve, reject) {
            const xhr = new XMLHttpRequest();
            let url = `${baseUrl}${normalizedPath}`;

            if (normalizedMethod === "GET") {
                const queryString = toQueryString(data);
                if (queryString) {
                    url += (url.indexOf("?") === -1 ? "?" : "&") + queryString;
                }
            }

            xhr.timeout = 15000;

            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) {
                    return;
                }

                const jsonResponse = safeParseJson(xhr.responseText);

                if (hasCallback) {
                    callback(xhr.status, jsonResponse);
                    return;
                }

                if (xhr.status >= 200 && xhr.status < 300) {
                    resolve(jsonResponse);
                } else {
                    reject({ status: xhr.status, data: jsonResponse });
                }
            };

            const handleTransportError = function(message) {
                const payload = { status: 0, data: { error: message } };
                if (hasCallback) {
                    callback(0, payload.data);
                } else {
                    reject(payload);
                }
            };

            xhr.onerror = function() {
                handleTransportError("Network error");
            };

            xhr.ontimeout = function() {
                handleTransportError("Request timeout");
            };

            xhr.onabort = function() {
                handleTransportError("Request aborted");
            };

            xhr.open(normalizedMethod, url, true);
            xhr.setRequestHeader("Accept", "application/json");

            if (normalizedMethod === "GET") {
                xhr.send();
                return;
            }

            if (normalizedMethod === "DELETE" && data === undefined) {
                xhr.send();
                return;
            }

            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(data || {}));
        };

        if (hasCallback) {
            executor(function() {}, function() {});
            return;
        }

        return new Promise(executor);
    }

    return {
        setBaseUrl(url) {
            baseUrl = normalizeBaseUrl(url);
        },

        getBaseUrl() {
            return baseUrl;
        },

        register(login, password, name, cb) {
            return sendRequest("POST", "/api/register", { login, password, name }, cb);
        },

        login(login, password, cb) {
            return sendRequest("POST", "/api/login", { login, password }, cb);
        },

        getUserProfile(userId, cb) {
            return sendRequest("GET", "/api/user/profile", { user_id: userId }, cb);
        },

        updateUserProfile(userId, data, cb) {
            const payload = Object.assign({ user_id: userId }, data || {});
            return sendRequest("PATCH", "/api/user/profile", payload, cb);
        },

        searchUsers(query, cb) {
            return sendRequest("GET", "/api/users/search", { query }, cb);
        },

        getChats(userId, limit, offset, cb) {
            const safeLimit = limit === undefined ? 50 : limit;
            const safeOffset = offset === undefined ? 0 : offset;
            return sendRequest(
                "GET",
                "/api/chats",
                { user_id: userId, limit: safeLimit, offset: safeOffset },
                cb
            );
        },

        createGroupChat(name, creatorId, participants, cb) {
            return sendRequest(
                "POST",
                "/api/chats/group",
                { name, creator_id: creatorId, participants },
                cb
            );
        },

        getChatInfo(chatId, userId, cb) {
            return sendRequest("GET", `/api/chat/${chatId}`, { user_id: userId }, cb);
        },

        renameChat(chatId, userId, name, cb) {
            return sendRequest("PATCH", `/api/chat/${chatId}`, { user_id: userId, name }, cb);
        },

        addUserToChat(chatId, requesterId, userId, cb) {
            return sendRequest(
                "POST",
                `/api/chat/${chatId}/users/add`,
                { requester_id: requesterId, user_id: userId },
                cb
            );
        },

        removeUserFromChat(chatId, requesterId, userId, cb) {
            return sendRequest(
                "POST",
                `/api/chat/${chatId}/users/remove`,
                { requester_id: requesterId, user_id: userId },
                cb
            );
        },

        leaveChat(chatId, userId, cb) {
            return sendRequest("POST", `/api/chat/${chatId}/leave`, { user_id: userId }, cb);
        },

        sendMessage(senderId, content, chatId, receiverId, cb) {
            const payload = {
                sender_id: senderId,
                content,
                chat_id: chatId === undefined || chatId === null ? 0 : chatId
            };
            if (payload.chat_id === 0) {
                payload.receiver_id = receiverId;
            }
            return sendRequest("POST", "/api/messages/send", payload, cb);
        },

        getMessages(chatId, userId, limit, offset, cb) {
            const safeLimit = limit === undefined ? 50 : limit;
            const safeOffset = offset === undefined ? 0 : offset;
            return sendRequest(
                "GET",
                "/api/messages",
                { chat_id: chatId, user_id: userId, limit: safeLimit, offset: safeOffset },
                cb
            );
        },

        searchMessages(query, userId, chatId, limit, offset, cb) {
            const safeLimit = limit === undefined ? 50 : limit;
            const safeOffset = offset === undefined ? 0 : offset;
            const params = { query, user_id: userId, limit: safeLimit, offset: safeOffset };
            if (chatId !== undefined && chatId !== null && chatId !== 0) {
                params.chat_id = chatId;
            }
            return sendRequest("GET", "/api/messages/search", params, cb);
        },

        editMessage(messageId, userId, content, cb) {
            return sendRequest("PATCH", `/api/messages/${messageId}`, { user_id: userId, content }, cb);
        },

        deleteMessage(messageId, userId, cb) {
            return sendRequest("DELETE", `/api/messages/${messageId}?user_id=${encodeURIComponent(String(userId))}`, undefined, cb);
        },

        setTyping(chatId, userId, isTyping, cb) {
            return sendRequest(
                "POST",
                `/api/chat/${chatId}/typing`,
                { chat_id: chatId, user_id: userId, is_typing: Boolean(isTyping) },
                cb
            );
        },

        getTyping(chatId, userId, cb) {
            return sendRequest(
                "GET",
                `/api/chat/${chatId}/typing`,
                { chat_id: chatId, user_id: userId },
                cb
            );
        }
    };
})();
