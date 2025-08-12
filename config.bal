// FHIR server configuration
configurable string base = ?;
configurable string tokenUrl = ?;
configurable string clientIdValue = ?;
configurable string clientSecret = ?;
configurable string[] scopesArray = ["system/Patient.read", "system/Patient.create", "system/Observation.read", "system/AllergyIntolerance.read"];

// Database configuration
configurable string dbHost = "localhost";
configurable int dbPort = 3306;
configurable string dbName = "healthcare_config";
configurable string dbUsername = "root";
configurable string dbPassword = "12345678";

// Service port configuration
configurable int servicePort = 9090;