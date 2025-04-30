trigger CareObservation on Care_Observation__c (after insert) {
    AgentforceHandler.invokeAgentforceForCareObservation(Trigger.new[0].Id);
}