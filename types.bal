import ballerinax/health.fhir.r4 as r4;

// Request payload for patient member ID
public type PatientRequest record {|
    string patientMemberId;
|};

// Response for the API
public type ApiResponse record {|
    string status;
    string message;
    string? patientId?;
|};

// Configuration for external API endpoints
public type ExternalApiConfig record {|
    string jsonEndpoint;
    string xmlEndpoint;
|};

// Allergy intolerance data structure for JSON endpoint
public type AllergyIntoleranceData record {|
    string resourceType;
    string id?;
    string patientReference;
    r4:CodeableConcept code;
    string clinicalStatus?;
    string verificationStatus?;
    string 'type?;
    string category?;
    string criticality?;
|};