import ballerinax/health.clients.fhir;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;

// FHIR client configuration
fhir:FHIRConnectorConfig cernerConfiuration = {
    baseURL: base,
    mimeType: fhir:FHIR_JSON,
    authConfig: {
        tokenUrl: tokenUrl,
        clientId: clientIdValue,
        clientSecret: clientSecret,
        scopes: scopesArray
    }
};

// Initialize FHIR connector
final fhir:FHIRConnector fhirConnectorObject = check new (cernerConfiuration);

// Initialize database connection pool
final mysql:Client dbClient = check new (
    host = dbHost,
    port = dbPort,
    database = dbName,
    user = dbUsername,
    password = dbPassword
);