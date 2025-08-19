# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "mcp[cli]==1.7.1",
#     "requests==2.32.3",
# ]
# ///
from mcp.server.lowlevel import Server
import mcp.types as types
import anyio
import httpx
from mcp.shared.session import RequestResponder
from mcp.server.session import ServerSession
from typing import TypeVar, Any
import types as pytypes
from mcp.shared.context import RequestContext

LifespanResultT = TypeVar("LifespanResultT")


GODOT_HTTP_SERVER_BASE_URL = "http://localhost:3571"

server = Server("gdai-mcp-godot")


_original_handle_message = server._handle_message
async def _handle_message(
    self,
    message: RequestResponder[types.ClientRequest, types.ServerResult]
    | types.ClientNotification
    | Exception,
    session: ServerSession,
    lifespan_context: LifespanResultT,
    raise_exceptions: bool = False,
):
    try:
        if isinstance(message, types.ClientNotification):
            client_params = session.client_params
            await http_post(GODOT_HTTP_SERVER_BASE_URL + "/client_initialized", {
                "protocol_version": client_params.protocolVersion,
                "client_name": client_params.clientInfo.name,
                "client_version": client_params.clientInfo.version,
            })

    except Exception as e:
        pass
    return await _original_handle_message(message, session, lifespan_context, raise_exceptions)

server._handle_message = pytypes.MethodType(_handle_message, server)


async def http_get(
    url: str,
    body = None
):
    async with httpx.AsyncClient() as client:
        response = await client.request(method="GET", url=url, json=body)
        response.raise_for_status()
        return response.json()


async def http_post(
    url: str,
    body
):
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=body)
        response.raise_for_status()
        return response.json()


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    json = await http_get(GODOT_HTTP_SERVER_BASE_URL + "/tools")
    return json["mcp_tools"]



@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list:
    json = await http_post(GODOT_HTTP_SERVER_BASE_URL + "/call-tool", {
        "tool_name": name,
        "tool_args": arguments
    })

    if json["is_error"]:
        raise Exception(
            f"Error calling tool {name}: {json['tool_call_result']}"
        )

    type = json["type"]
    if type == "image":
        if "mime_type" not in json:
            mime_type = "image/jpg"
        mime_type = json["mime_type"]
        return [types.ImageContent(type="image", mimeType=mime_type, data=json["tool_call_result"])]
    else:
        return [types.TextContent(type="text", text=json["tool_call_result"])]


@server.list_prompts()
async def list_prompts() -> list[types.Prompt]:
    json = await http_get(GODOT_HTTP_SERVER_BASE_URL + "/prompts")
    prompts_arr = json["mcp_prompts"]

    ret  = []
    for prompt in prompts_arr:
        ret.append(
            types.Prompt(
                name=prompt["name"],
                description=prompt["description"],
                arguments=[]
            )
        )

    return ret


@server.get_prompt()
async def get_prompt(name: str, arguments: dict[str, str] | None) -> types.GetPromptResult:
    if name != "gdai-mcp-default-prompt":
        raise ValueError(f"Unknown prompt: {name}")
    
    json = await http_get(GODOT_HTTP_SERVER_BASE_URL + f"/prompt", {
        "prompt_name": name,
        "prompt_args": arguments
    })

    if "is_error" in json and json["is_error"]:
        raise ValueError(json["result"])
    
    messages = json["messages"]

    return types.GetPromptResult(
        messages=[
            types.PromptMessage(
                role=message["role"],
                content=types.TextContent(type="text", text=message["content"]["text"])
            ) for message in messages
        ],
        prompt_name=name
    )


async def run():
    from mcp.server.stdio import stdio_server

    async with stdio_server() as streams:
        await server.run(
            streams[0], streams[1], server.create_initialization_options()
        )


if __name__ == "__main__":
    anyio.run(run)