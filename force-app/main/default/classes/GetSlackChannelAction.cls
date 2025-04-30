/**
* GetSlackChannelAction
* 
* This class provides a Flow-invocable action to search for a Slack channel by name within a specific workspace
* in a Slack Enterprise Grid environment. It handles the pagination of results and provides detailed channel information.
* 
* The process:
* 1. Takes a workspace name and channel name as input
* 2. Queries auth.teams.list to find the workspace ID from the name
* 3. Uses the workspace ID to search for the channel using conversations.list
* 4. Returns channel details if found
*/
public class GetSlackChannelAction {
          
    /**
    * Input class for the Flow action
    * Requires both workspace name and channel name to perform the search
    */
    public class ChannelSearchInput {
        @InvocableVariable(required=true description='Name of the channel to search for')
        public String channel_name;
              
        @InvocableVariable(required=true description='Name of the Slack workspace')
        public String workspace_name;
    }
          
    /**
    * Output class containing channel details or error information
    * Returns basic channel information including ID, name, member count, and topic
    */
    public class ChannelSearchOutput {
        @InvocableVariable(description='Channel ID')
        public String channel_id;
              
        @InvocableVariable(description='Channel Name')
        public String channel_name;
              
        @InvocableVariable(description='Number of members in the channel')
        public Integer num_members;
              
        @InvocableVariable(description='Channel topic')
        public String topic;
              
        @InvocableVariable(description='Error message if search failed')
        public String error_message;
    }
          
    // ------------------------
    // API Response Structures
    // ------------------------
          
    /**
    * Response structure for auth.teams.list endpoint
    * Used to find workspace/team ID from workspace name
    */
    private class TeamsListResponse {
        public Boolean ok;
        public List<Team> teams;
        public ResponseMetadata response_metadata;
        public String error;
    }
          
    /**
    * Structure representing a Slack workspace/team
    */
    private class Team {
        public String id;
        public String name;
    }
          
    /**
    * Response structure for conversations.list endpoint
    * Contains list of channels and pagination metadata
    */
    private class SlackResponse {
        public Boolean ok;
        public List<Channel> channels;
        public ResponseMetadata response_metadata;
        public String error;
    }
          
    /**
    * Metadata structure containing pagination information
    */
    private class ResponseMetadata {
        public String next_cursor;
    }
          
    /**
    * Structure representing a Slack channel
    * Contains only the fields we need for our output
    */
    private class Channel {
        public String id;
        public String name;
        public Integer num_members;
        public Topic topic;
    }
          
    /**
    * Structure representing a channel's topic
    */
    private class Topic {
        public String value;
    }
          
    /**
    * Main invocable method for the Flow action
    * Processes a list of inputs (bulk processing support) and returns corresponding outputs
    */
    @InvocableMethod(label='Get Slack Channel' 
                    description='Searches for a Slack channel by name in specified workspace and returns its details')
    public static List<ChannelSearchOutput> searchChannel(List<ChannelSearchInput> inputs) {
        List<ChannelSearchOutput> outputs = new List<ChannelSearchOutput>();
              
        // Process each input in the list (supporting bulk operations)
        for(ChannelSearchInput input : inputs) {
            ChannelSearchOutput output = new ChannelSearchOutput();
                  
            try {
                // Step 1: Get the workspace ID from the workspace name
                String teamId = getWorkspaceId(input.workspace_name);
                      
                if (teamId == null) {
                    output.error_message = 'Workspace "' + input.workspace_name + '" not found';
                    outputs.add(output);
                    continue;
                }
                      
                // Step 2: Search for the channel in the identified workspace
                Channel foundChannel = searchAllChannels(input.channel_name, teamId);
                      
                // Step 3: Process results
                if (foundChannel != null) {
                    // Channel found - populate output with channel details
                    output.channel_id = foundChannel.id;
                    output.channel_name = foundChannel.name;
                    output.num_members = foundChannel.num_members;
                          
                    if (foundChannel.topic != null) {
                        output.topic = foundChannel.topic.value;
                    }
                } else {
                    // Channel not found
                    output.error_message = 'Channel not found';
                }
                      
            } catch(Exception e) {
                // Handle any errors that occur during processing
                output.error_message = 'Error: ' + e.getMessage();
                System.debug('Error details: ' + e.getStackTraceString());
            }
                  
            outputs.add(output);
        }
              
        return outputs;
    }
          
    /**
    * Gets the workspace ID for a given workspace name using auth.teams.list
    * This method handles the Enterprise Grid workspace lookup
    * 
    * @param workspaceName The name of the workspace to find
    * @return The workspace ID if found, null if not found
    */
    private static String getWorkspaceId(String workspaceName) {
        // Initialize HTTP request
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:Slack_API/auth.teams.list');
        request.setMethod('GET');
              
        // Make the API call
        HttpResponse response = http.send(request);
              
        // Check for successful response
        if (response.getStatusCode() != 200) {
            throw new CalloutException('Teams list failed with status code: ' + response.getStatusCode());
        }
              
        // Parse the response
        TeamsListResponse teamsResponse = (TeamsListResponse)JSON.deserialize(
            response.getBody(), 
            TeamsListResponse.class
        );
              
        if (!teamsResponse.ok) {
            throw new CalloutException('Teams list not OK: ' + teamsResponse.error);
        }
              
        // Search for matching workspace name
        for (Team team : teamsResponse.teams) {
            if (team.name.equalsIgnoreCase(workspaceName)) {
                return team.id;
            }
        }
              
        // No matching workspace found
        return null;
    }
          
    /**
    * Searches for a channel by name within a specific workspace
    * Handles pagination to search through all available channels
    * 
    * @param channelName The name of the channel to find
    * @param teamId The ID of the workspace to search in
    * @return Channel object if found, null if not found
    */
    private static Channel searchAllChannels(String channelName, String teamId) {
        String cursor = null;
              
        do {
            // Construct endpoint URL with team_id and pagination cursor
            String endpoint = 'callout:Slack_API/conversations.list?team_id=' + teamId;
            if (String.isNotBlank(cursor)) {
                endpoint += '&cursor=' + EncodingUtil.urlEncode(cursor, 'UTF-8');
            }
                  
            // Initialize HTTP request
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(endpoint);
            request.setMethod('GET');
                  
            // Make the API call
            HttpResponse response = http.send(request);
                  
            // Check for successful response
            if (response.getStatusCode() != 200) {
                throw new CalloutException('Failed with status code: ' + response.getStatusCode());
            }
                  
            // Parse the response
            SlackResponse slackResponse = (SlackResponse)JSON.deserialize(
                response.getBody(), 
                SlackResponse.class
            );
                  
            if (!slackResponse.ok) {
                throw new CalloutException('Slack API response not OK: ' + slackResponse.error);
            }
                  
            // Search through current page of channels
            for (Channel channel : slackResponse.channels) {
                if (channel.name.equalsIgnoreCase(channelName)) {
                    return channel;
                }
            }
                  
            // Get cursor for next page of results
            cursor = (slackResponse.response_metadata != null) ? 
                    slackResponse.response_metadata.next_cursor : null;
                          
        } while (String.isNotBlank(cursor)); // Continue while there are more pages
              
        // Channel not found after searching all pages
        return null;
    }
}