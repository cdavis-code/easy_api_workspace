# HTTP Transport

<cite>
**Referenced Files in This Document**
- [README.md](file://README.md)
- [pubspec.yaml](file://pubspec.yaml)
- [packages/easy_mcp_annotations/lib/mcp_annotations.dart](file://packages/easy_mcp_annotations/lib/mcp_annotations.dart)
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart)
- [packages/easy_mcp_generator/lib/builder/templates.dart](file://packages/easy_mcp_generator/lib/builder/templates.dart)
- [packages/easy_mcp_generator/lib/builder/schema_builder.dart](file://packages/easy_mcp_generator/lib/builder/schema_builder.dart)
- [example/bin/example.mcp.dart](file://example/bin/example.mcp.dart)
- [example/bin/example.dart](file://example/bin/example.dart)
- [example/lib/src/user_store.dart](file://example/lib/src/user_store.dart)
- [example/lib/src/todo_store.dart](file://example/lib/src/todo_store.dart)
- [example/pubspec.yaml](file://example/pubspec.yaml)
</cite>

## Update Summary
**Changes Made**
- Enhanced Core Components section to reflect comprehensive port customization and address binding capabilities
- Expanded Port Configuration and Loopback Binding section with detailed Docker container and remote access scenarios
- Added sophisticated transport detection mechanisms for HTTP vs stdio transport selection
- Updated Server Lifecycle Management to include proper cleanup procedures
- Enhanced Practical Examples with dynamic configuration scenarios for various deployment environments
- Added comprehensive security considerations for Docker and remote access deployments
- Added automatic JSON metadata generation capability with .mcp.json file output

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Security Considerations](#security-considerations)
10. [Practical Examples](#practical-examples)
11. [Conclusion](#conclusion)

## Introduction
This document explains the HTTP transport implementation for Easy MCP's web-based communication system. It covers how the Shelf framework integrates with the MCP server to enable HTTP-based tool invocation, the bidirectional streaming architecture using StreamController and StreamChannel, comprehensive port configuration and address binding capabilities, server lifecycle management, template generation for HTTP endpoints, response buffering with completer queues, automatic JSON metadata generation, and practical guidance for testing, monitoring, error handling, and performance optimization across various deployment scenarios including Docker containers and remote access environments.

## Project Structure
The repository provides:
- Annotations and generator for building HTTP or stdio MCP servers with dynamic configuration
- Example application demonstrating HTTP transport usage with configurable port and address
- Automatic JSON metadata generation for tool schemas and descriptions
- Tests validating the generated HTTP server template with dynamic settings

```mermaid
graph TB
subgraph "Annotations"
A["mcp_annotations.dart<br/>Dynamic transport & config"]
end
subgraph "Generator"
B["mcp_builder.dart<br/>Sophisticated transport detection"]
C["templates.dart<br/>Dynamic port/address templates"]
D["schema_builder.dart"]
end
subgraph "Example"
E["example.mcp.dart<br/>Generated HTTP server"]
F["user_store.dart"]
G["todo_store.dart"]
H["example.dart<br/>@Mcp transport config"]
end
subgraph "Metadata"
I["example.mcp.json<br/>Automatic JSON schemas"]
end
subgraph "Docs"
J["README.md"]
K["example/pubspec.yaml"]
end
A --> B
B --> C
C --> E
D --> C
F --> E
G --> E
H --> E
B --> I
J --> K
```

**Diagram sources**
- [packages/easy_mcp_annotations/lib/mcp_annotations.dart:1-241](file://packages/easy_mcp_annotations/lib/mcp_annotations.dart#L1-L241)
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:1-834](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L1-L834)
- [packages/easy_mcp_generator/lib/builder/templates.dart:282-630](file://packages/easy_mcp_generator/lib/builder/templates.dart#L282-L630)
- [packages/easy_mcp_generator/lib/builder/schema_builder.dart:1-99](file://packages/easy_mcp_generator/lib/builder/schema_builder.dart#L1-L99)
- [example/bin/example.mcp.dart:1-500](file://example/bin/example.mcp.dart#L1-L500)
- [example/bin/example.dart:6](file://example/bin/example.dart#L6)
- [example/lib/src/user_store.dart:1-158](file://example/lib/src/user_store.dart#L1-L158)
- [example/lib/src/todo_store.dart:1-236](file://example/lib/src/todo_store.dart#L1-L236)
- [README.md:1-168](file://README.md#L1-L168)
- [example/pubspec.yaml:1-22](file://example/pubspec.yaml#L1-L22)

**Section sources**
- [README.md:1-168](file://README.md#L1-L168)
- [pubspec.yaml:1-64](file://pubspec.yaml#L1-L64)

## Core Components
- Annotations define transport mode selection (HTTP vs stdio) and dynamic configuration including port and address settings.
- The generator performs sophisticated transport detection and extracts configuration parameters from annotations.
- The HttpTemplate generates Shelf-based HTTP servers with dynamic port and address binding.
- The example demonstrates HTTP transport with configurable port (8080) and address ('0.0.0.0').
- Automatic JSON metadata generation creates .mcp.json files with tool schemas and descriptions.

Key responsibilities:
- McpTransport enum selects HTTP transport with dynamic configuration support.
- McpBuilder performs transport detection and extracts port/address from annotations.
- HttpTemplate generates dynamic server code with configurable port and address binding.
- Example server demonstrates HTTP transport with custom port and address configuration.
- Automatic JSON metadata generation provides tool schemas for external clients.

**Updated** Enhanced transport detection and dynamic configuration capabilities with comprehensive port customization and automatic JSON metadata generation

**Section sources**
- [packages/easy_mcp_annotations/lib/mcp_annotations.dart:9-90](file://packages/easy_mcp_annotations/lib/mcp_annotations.dart#L9-L90)
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:559-734](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L559-L734)
- [packages/easy_mcp_generator/lib/builder/templates.dart:303-537](file://packages/easy_mcp_generator/lib/builder/templates.dart#L303-L537)
- [example/bin/example.dart:6](file://example/bin/example.dart#L6)

## Architecture Overview
The HTTP transport architecture connects incoming HTTP requests to the MCP server via a bidirectional stream with dynamic configuration support. The Shelf handler validates the request, forwards the payload to the MCP server through a StreamChannel, and returns the serialized response. The system now includes automatic JSON metadata generation for enhanced tool discovery and schema validation.

```mermaid
graph TB
Client["HTTP Client"]
Shelf["Shelf Handler<br/>handleRequest()"]
SC1["clientToServer<br/>StreamController<String>"]
SC2["serverToClient<br/>StreamController<String>.broadcast"]
Channel["StreamChannel<String>"]
MCP["MCPServerWithTools"]
Queue["Response Queue<br/>List<Completer<String>>"]
Config["Dynamic Config<br/>Port & Address"]
Metadata["JSON Metadata<br/>.mcp.json"]
Client --> Shelf
Shelf --> Config
Config --> Shelf
Shelf --> SC1
SC1 --> Channel
Channel --> MCP
MCP --> SC2
SC2 --> Shelf
Shelf --> Queue
Queue --> Shelf
MCP --> Metadata
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:471-501](file://packages/easy_mcp_generator/lib/builder/templates.dart#L471-L501)
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:626-734](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L626-L734)
- [example/bin/example.mcp.dart:17-67](file://example/bin/example.mcp.dart#L17-L67)

## Detailed Component Analysis

### Sophisticated Transport Detection and Dynamic Configuration
- The generator performs comprehensive transport detection across top-level functions, classes, and methods.
- Dynamic configuration extraction supports port and address parameters for HTTP transport.
- Transport detection prioritizes explicit annotation values over defaults.
- The system handles both enum-based and index-based transport specification.

```mermaid
sequenceDiagram
participant Annotation as "@Mcp Annotation"
participant Builder as "McpBuilder"
participant Transport as "Transport Detection"
participant Config as "Configuration Extraction"
Annotation->>Builder : "transport, port, address"
Builder->>Transport : "_findTransport()"
Transport->>Transport : "Check top-level, classes, methods"
Transport-->>Builder : "transport type"
Builder->>Config : "_findPort(), _findAddress()"
Config->>Config : "Extract numeric port & string address"
Config-->>Builder : "port & address values"
Builder-->>Builder : "Generate HttpTemplate with config"
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:559-734](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L559-L734)
- [packages/easy_mcp_annotations/lib/mcp_annotations.dart:54-89](file://packages/easy_mcp_annotations/lib/mcp_annotations.dart#L54-L89)

**Section sources**
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:559-734](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L559-L734)
- [packages/easy_mcp_annotations/lib/mcp_annotations.dart:54-89](file://packages/easy_mcp_annotations/lib/mcp_annotations.dart#L54-L89)

### Shelf Integration and Request Routing
- The generated server defines a Shelf route handler that accepts only POST requests.
- Non-POST requests return an appropriate HTTP error status.
- On successful POST, the handler reads the request body, enqueues a Completer for response synchronization, and forwards the body to the MCP server via the client-to-server stream.

```mermaid
sequenceDiagram
participant Client as "HTTP Client"
participant Shelf as "Shelf Handler"
participant MCP as "MCPServerWithTools"
participant Queue as "Response Queue"
Client->>Shelf : "POST /"
Shelf->>Shelf : "validate method"
Shelf->>Shelf : "readAsString()"
Shelf->>Queue : "add Completer"
Shelf->>MCP : "clientToServer.add(body)"
MCP-->>Shelf : "serverToClient.stream"
Shelf->>Queue : "complete(completer)"
Shelf-->>Client : "200 OK JSON response"
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:471-501](file://packages/easy_mcp_generator/lib/builder/templates.dart#L471-L501)
- [example/bin/example.mcp.dart:38-53](file://example/bin/example.mcp.dart#L38-L53)

**Section sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:471-501](file://packages/easy_mcp_generator/lib/builder/templates.dart#L471-L501)
- [example/bin/example.mcp.dart:38-53](file://example/bin/example.mcp.dart#L38-L53)

### Bidirectional Streaming with StreamController and StreamChannel
- Two StreamControllers manage directions:
  - clientToServer: receives HTTP request bodies and forwards to MCP.
  - serverToClient: broadcasts MCP responses back to the HTTP handler.
- StreamChannel connects these streams to the MCP server's expected channel interface.
- The MCP server registers tools and serializes results for transport.

```mermaid
classDiagram
class StreamController_T_ {
+stream Stream
+sink
+close()
}
class StreamChannel_T_ {
+StreamChannel(stream, sink)
}
class MCPServerWithTools {
+fromStreamChannel(...)
+registerTool(...)
}
StreamController_T_ <.. StreamChannel_T_ : "constructs"
StreamChannel_T_ --> MCPServerWithTools : "provides channel"
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:451-461](file://packages/easy_mcp_generator/lib/builder/templates.dart#L451-L461)
- [packages/easy_mcp_generator/lib/builder/templates.dart:503-513](file://packages/easy_mcp_generator/lib/builder/templates.dart#L503-L513)
- [example/bin/example.mcp.dart:18-26](file://example/bin/example.mcp.dart#L18-L26)

**Section sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:451-461](file://packages/easy_mcp_generator/lib/builder/templates.dart#L451-L461)
- [packages/easy_mcp_generator/lib/builder/templates.dart:503-513](file://packages/easy_mcp_generator/lib/builder/templates.dart#L503-L513)
- [example/bin/example.mcp.dart:18-26](file://example/bin/example.mcp.dart#L18-L26)

### Dynamic Port Configuration and Address Binding
- The generated HTTP server supports dynamic port configuration extracted from @Mcp annotations.
- Address binding supports both loopback interface ('127.0.0.1') and external interfaces ('0.0.0.0').
- The builder extracts port and address values from annotations with fallback to defaults.
- Conditional imports optimize imports based on address type (uses dart:io for loopback, string literals for custom addresses).

```mermaid
flowchart TD
Start(["Server Startup"]) --> Detect["Detect Transport & Config"]
Detect --> Port["Extract Port (default: 3000)"]
Detect --> Address["Extract Address (default: '127.0.0.1')"]
Port --> Bind["Bind to Address"]
Address --> Bind
Bind --> Listen["Listen for requests on Port"]
Listen --> Done(["Server Running"])
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:626-734](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L626-L734)
- [packages/easy_mcp_generator/lib/builder/templates.dart:322-325](file://packages/easy_mcp_generator/lib/builder/templates.dart#L322-L325)
- [example/bin/example.mcp.dart:55-59](file://example/bin/example.mcp.dart#L55-L59)

**Updated** Enhanced with dynamic configuration extraction and conditional imports for comprehensive deployment scenarios

**Section sources**
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:626-734](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L626-L734)
- [packages/easy_mcp_generator/lib/builder/templates.dart:322-325](file://packages/easy_mcp_generator/lib/builder/templates.dart#L322-L325)
- [example/bin/example.mcp.dart:55-59](file://example/bin/example.mcp.dart#L55-L59)

### Server Lifecycle Management
- The server starts the Shelf HTTP server with dynamic configuration, waits for the MCP server to complete, and closes resources cleanly.
- Streams and controllers are closed after the MCP server finishes.
- Proper cleanup ensures graceful shutdown and resource deallocation.

```mermaid
flowchart TD
A["Start main()"] --> B["Create StreamControllers"]
B --> C["Create StreamChannel"]
C --> D["Start MCPServerWithTools"]
D --> E["Start Shelf server with dynamic config"]
E --> F{"MCP done?"}
F --> |No| E
F --> |Yes| G["Close Shelf server"]
G --> H["Close StreamControllers"]
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:450-501](file://packages/easy_mcp_generator/lib/builder/templates.dart#L450-L501)
- [example/bin/example.mcp.dart:63-67](file://example/bin/example.mcp.dart#L63-L67)

**Section sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:450-501](file://packages/easy_mcp_generator/lib/builder/templates.dart#L450-L501)
- [example/bin/example.mcp.dart:63-67](file://example/bin/example.mcp.dart#L63-L67)

### Template Generation Process
- The generator extracts tool definitions and metadata from annotated libraries.
- It emits an HTTP server template that includes:
  - Imports for Shelf and StreamChannel with conditional dart:io imports
  - StreamControllers and StreamChannel construction
  - Response buffering via a queue of Completers
  - Tool registration and handlers
  - Server startup with dynamic port and address configuration
  - Server lifecycle cleanup

```mermaid
sequenceDiagram
participant Builder as "McpBuilder"
participant Extract as "_extractAllTools()"
participant Template as "HttpTemplate.generate()"
participant Config as "Dynamic Config"
participant Output as ".mcp.dart"
Builder->>Extract : "scan for @Tool annotations"
Extract-->>Builder : "tools metadata"
Builder->>Config : "extract port & address"
Config-->>Builder : "dynamic configuration"
Builder->>Template : "generate(tools, port, address)"
Template-->>Output : "write generated HTTP server"
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:559-624](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L559-L624)
- [packages/easy_mcp_generator/lib/builder/templates.dart:303-537](file://packages/easy_mcp_generator/lib/builder/templates.dart#L303-L537)

**Section sources**
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:559-624](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L559-L624)
- [packages/easy_mcp_generator/lib/builder/templates.dart:303-537](file://packages/easy_mcp_generator/lib/builder/templates.dart#L303-L537)

### Response Buffering Mechanism
- A queue of Completers ensures that responses from the MCP server match the correct request.
- When a response arrives on the server-to-client stream, the head of the queue completes, unblocking the corresponding request handler.

```mermaid
flowchart TD
Req["Incoming Request"] --> Enqueue["Enqueue Completer"]
Enqueue --> Send["Send body to MCP"]
Send --> Resp["MCP Response"]
Resp --> Dequeue["Dequeue Completer"]
Dequeue --> Complete["Complete Future"]
Complete --> Reply["Return HTTP Response"]
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:464-469](file://packages/easy_mcp_generator/lib/builder/templates.dart#L464-L469)
- [example/bin/example.mcp.dart:30-36](file://example/bin/example.mcp.dart#L30-L36)

**Section sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:464-469](file://packages/easy_mcp_generator/lib/builder/templates.dart#L464-L469)
- [example/bin/example.mcp.dart:30-36](file://example/bin/example.mcp.dart#L30-L36)

### Tool Registration and Serialization
- Tools are registered with input schemas derived from parameter introspection.
- Results are serialized to JSON for transport and returned as HTTP responses.

```mermaid
classDiagram
class SchemaBuilder {
+fromType(rawType) String
+fromSchemaMap(map) String
+buildObjectSchema(params) String
}
class MCPServerWithTools {
+registerTool(tool, handler)
+_serializeResult(result) String
}
SchemaBuilder --> MCPServerWithTools : "builds input schemas"
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/schema_builder.dart:1-99](file://packages/easy_mcp_generator/lib/builder/schema_builder.dart#L1-L99)
- [packages/easy_mcp_generator/lib/builder/templates.dart:503-536](file://packages/easy_mcp_generator/lib/builder/templates.dart#L503-L536)

**Section sources**
- [packages/easy_mcp_generator/lib/builder/schema_builder.dart:1-99](file://packages/easy_mcp_generator/lib/builder/schema_builder.dart#L1-L99)
- [packages/easy_mcp_generator/lib/builder/templates.dart:503-536](file://packages/easy_mcp_generator/lib/builder/templates.dart#L503-L536)

### Automatic JSON Metadata Generation
- The generator can produce .mcp.json files containing complete tool metadata and JSON schemas.
- Metadata includes tool names, descriptions, parameter schemas, and required fields.
- Supports rich parameter metadata including titles, descriptions, examples, and validation constraints.
- Enables external clients to discover and validate tool usage without executing code.

```mermaid
flowchart TD
A["@Mcp(generateJson: true)"] --> B["McpBuilder detects generateJson"]
B --> C["Extract tool metadata"]
C --> D["Build JSON schema"]
D --> E[".mcp.json file"]
E --> F["External client consumption"]
```

**Diagram sources**
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:552-578](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L552-L578)
- [packages/easy_mcp_annotations/lib/mcp_annotations.dart:60-84](file://packages/easy_mcp_annotations/lib/mcp_annotations.dart#L60-L84)

**Section sources**
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:552-578](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L552-L578)
- [packages/easy_mcp_annotations/lib/mcp_annotations.dart:60-84](file://packages/easy_mcp_annotations/lib/mcp_annotations.dart#L60-L84)

## Dependency Analysis
- The example depends on Shelf and StreamChannel to implement HTTP transport and bidirectional streaming.
- The generator depends on the annotations package and uses dart_mcp for server scaffolding.
- Dynamic configuration requires proper import handling based on address type.
- Automatic JSON metadata generation adds optional .mcp.json file output.

```mermaid
graph LR
Annotations["easy_mcp_annotations"] --> Builder["mcp_builder.dart"]
Builder --> Templates["templates.dart"]
Templates --> Example[".mcp.dart (generated)"]
Builder --> JsonMetadata[".mcp.json (optional)"]
Example --> Shelf["shelf"]
Example --> StreamChannel["stream_channel"]
```

**Diagram sources**
- [packages/easy_mcp_annotations/lib/mcp_annotations.dart:1-241](file://packages/easy_mcp_annotations/lib/mcp_annotations.dart#L1-L241)
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:1-834](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L1-L834)
- [packages/easy_mcp_generator/lib/builder/templates.dart:282-630](file://packages/easy_mcp_generator/lib/builder/templates.dart#L282-L630)
- [example/pubspec.yaml:11-22](file://example/pubspec.yaml#L11-L22)

**Section sources**
- [example/pubspec.yaml:11-22](file://example/pubspec.yaml#L11-L22)
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:559-624](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L559-L624)

## Performance Considerations
- Request handling is synchronous per request; ensure the MCP server remains responsive.
- Avoid blocking operations inside tool handlers to prevent queue backlog.
- Consider connection pooling and concurrency limits at the HTTP layer if scaling horizontally.
- Monitor queue depth and completion latency to detect backpressure.
- Dynamic configuration adds minimal overhead during server startup.
- JSON metadata generation occurs only when generateJson is enabled, adding minimal runtime cost.

## Troubleshooting Guide
Common issues and remedies:
- Method not allowed: Ensure clients send POST requests to the HTTP endpoint.
- Port conflicts: Change the port in the @Mcp annotation and rebuild.
- Address binding: Verify the server binds to the correct address; adjust address parameter if exposing externally.
- Resource cleanup: Verify server lifecycle closes streams and the HTTP server gracefully.
- Transport detection: Ensure @Mcp annotation is properly placed on top-level functions, classes, or methods.
- JSON metadata generation: Enable generateJson parameter to produce .mcp.json files for external clients.
- Missing dependencies: Ensure shelf and stream_channel packages are included in pubspec.yaml.

**Section sources**
- [packages/easy_mcp_generator/lib/builder/templates.dart:472-474](file://packages/easy_mcp_generator/lib/builder/templates.dart#L472-L474)
- [packages/easy_mcp_generator/lib/builder/mcp_builder.dart:626-734](file://packages/easy_mcp_generator/lib/builder/mcp_builder.dart#L626-L734)
- [packages/easy_mcp_generator/lib/builder/templates.dart:496-501](file://packages/easy_mcp_generator/lib/builder/templates.dart#L496-L501)

## Security Considerations
- CORS: The generated HTTP server uses `Access-Control-Allow-Origin: *` to allow any origin. This is appropriate for local development but **for production deployments, CORS should be configured via your reverse proxy** (e.g., nginx, Cloudflare, AWS API Gateway) rather than relying on the generated server's wildcard CORS. The reverse proxy should restrict allowed origins to your specific trusted domains.
- Authentication: No built-in authentication; integrate middleware or reverse proxy authentication as needed.
- HTTPS: The template binds to loopback and does not enable TLS; deploy behind a reverse proxy for TLS termination.
- Network exposure: The example demonstrates binding to '0.0.0.0' for external access; use '127.0.0.1' for local-only access.
- Dynamic configuration: Validate configuration inputs to prevent unexpected address/port combinations.
- Docker deployments: Use environment variables for port and address configuration to avoid hardcoding sensitive values.
- Remote access: Implement proper firewall rules and consider using VPN or SSH tunneling for secure remote access.
- JSON metadata: The .mcp.json files contain sensitive tool information; restrict access to authorized clients only.

**Updated** Enhanced security considerations for Docker and remote access deployments

## Practical Examples

### Local Development Configuration
- HTTP server startup with dynamic configuration:
  - Use @Mcp(transport: McpTransport.http, port: 8080, address: '127.0.0.1') to configure server binding for local development.
  - Run the generated server binary to start the Shelf HTTP server with custom port and loopback address.
  - The server prints the effective port after binding.
- Endpoint testing:
  - Send a POST request to the HTTP endpoint with a JSON payload compatible with the MCP server.
  - Expect a JSON response; verify non-POST requests receive an appropriate error status.

### Production Deployment Scenarios

#### Docker Container Configuration
- Environment-based configuration:
  - Use @Mcp(transport: McpTransport.http, port: 8080, address: '0.0.0.0') for Docker container deployments.
  - Expose port 8080 in Dockerfile: `EXPOSE 8080`
  - Run with: `docker run -p 8080:8080 your-mcp-image`
- Docker Compose example:
  ```yaml
  version: '3.8'
  services:
    mcp-server:
      build: .
      ports:
        - "8080:8080"
      environment:
        - MCP_PORT=8080
        - MCP_ADDRESS=0.0.0.0
      networks:
        - app-network
  
  networks:
    app-network:
      driver: bridge
  ```

#### Remote Access Configuration
- External network binding:
  - Use @Mcp(transport: McpTransport.http, port: 8080, address: '0.0.0.0') for remote access.
  - Configure firewall rules to allow inbound connections on the specified port.
  - Consider using a reverse proxy (Nginx/Apache) for SSL termination and load balancing.
- Cloud deployment example:
  - AWS EC2: Configure security group to allow inbound traffic on port 8080 from 0.0.0.0/0 or specific IP ranges.
  - Kubernetes: Use Service with type LoadBalancer or Ingress controller for external access.

### Integration with Web Clients
- Browser clients: Ensure CORS headers are set or serve via a trusted origin.
- Mobile applications: Configure network security policies to allow HTTP requests to the server.
- Desktop applications: Use standard HTTP client libraries with proper error handling.

### Transport Detection Scenarios
- Test different placement of @Mcp annotation (top-level function, class, method).
- Verify that configuration extraction works regardless of annotation location.

### Automatic JSON Metadata Generation
- Enable JSON metadata generation by setting generateJson: true in @Mcp annotation.
- The generator creates .mcp.json files with complete tool schemas and descriptions.
- External clients can consume .mcp.json for tool discovery and validation.
- Supports rich parameter metadata including titles, descriptions, examples, and validation constraints.

**Updated** Added comprehensive Docker container and remote access deployment scenarios

**Section sources**
- [example/bin/example.dart:6](file://example/bin/example.dart#L6)
- [example/bin/example.mcp.dart:55-59](file://example/bin/example.mcp.dart#L55-L59)
- [packages/easy_mcp_generator/lib/builder/templates.dart:471-501](file://packages/easy_mcp_generator/lib/builder/templates.dart#L471-L501)

## Conclusion
The Easy MCP HTTP transport leverages Shelf for request handling, StreamChannel for bidirectional streaming, and a completer-queue mechanism to synchronize responses. The generator automates server creation from annotated tool definitions with sophisticated transport detection and dynamic configuration extraction. The system now supports flexible port and address configuration, enabling deployment in various environments from local development to production deployments including Docker containers and remote access scenarios. The addition of automatic JSON metadata generation enhances tool discovery and external client integration. For production, consider CORS, authentication, and HTTPS via a reverse proxy, implement proper security measures for Docker deployments, and monitor performance to maintain responsiveness under load. The comprehensive configuration options and deployment flexibility make this solution suitable for diverse operational requirements.