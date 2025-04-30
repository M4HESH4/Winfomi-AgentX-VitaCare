public class AgentforceHandler {

    // Method to invoke the Agentforce agent when a CareObservation is created
    @future(callout=true)
    public static void invokeAgentforceForCareObservation(String careObjId) {
        
        Care_Observation__c obs = [SELECT Id,Name,Observed_Patient__c,Processing_Result__c,Numeric_Value__c,Unit_of_Measure__c,Expected_Value__c,Device__c FROM Care_Observation__c WHERE ID =:careObjId];

        System.debug('Entered invokeAgentforceForCareObservation method.');

        // Build a descriptive message from the CareObservation fields
        String userMessage = buildUserMessage(obs);
        System.debug('Constructed user message for agent: ' + userMessage);

        // Create a custom action to invoke the Agentforce agent
        Invocable.Action action = Invocable.Action.createCustomAction(
            'generateAiAgentResponse',
            'VitaCare_Agent' // Replace with your actual Agentforce API name
        );
        System.debug('Created Invocable Action for agent: VitaCare_Agent');

        // Set the user message as an input parameter to the agent
        action.setInvocationParameter('userMessage', userMessage);
        System.debug('Set invocation parameter userMessage to: ' + userMessage);

        // Invoke the agent and capture results
        List<Invocable.Action.Result> actionResults = action.invoke();
        System.debug('Invoked the agent and received results.');

        Invocable.Action.Result actionResult = actionResults[0];
        System.debug('Captured first result from agent response.');

        // If the agent call was successful, log the response
        if (actionResult.isSuccess()) {
            System.debug('Agent invocation successful.');
            System.debug('Session Id: ' + actionResult.getOutputParameters().get('sessionId'));
            System.debug('Agent Response: ' + actionResult.getOutputParameters().get('agentResponse'));
        } else {
            // Log any errors from the agent invocation
            System.debug('Agent invocation failed with errors: ' + actionResult.getErrors());
        }
    }

    // Helper method to format CareObservation details into a user message
    private static String buildUserMessage(Care_Observation__c obs) {
        System.debug('Building user message from Care_Observation__c record.');
        return 'Send the following message to #care-team-alerts-escalations slack channel (Channel Id:C08QE9ET7TN) in the Winfomi AgentX Workspace (WorkSpace Id:T08Q2B8DJEA), new Care Observation has been created with the following details:\n' +
               'Name: ' + obs.Name + '\n' +
               'Observed Patient: ' + obs.Observed_Patient__c + '\n' +
               'Processing Result: ' + obs.Processing_Result__c + '\n' +
               'Numeric Value: ' + obs.Numeric_Value__c + ' ' + obs.Unit_of_Measure__c + '\n' +
               'Expected Value: ' + obs.Expected_Value__c + '\n' +
               'Device Used: ' + obs.Device__c;
    }
}