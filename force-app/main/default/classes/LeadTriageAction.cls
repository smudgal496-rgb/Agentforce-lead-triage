public with sharing class LeadTriageAction {

    public class TriageResult {
        @InvocableVariable(label='Priority')
        public String priority;

        @InvocableVariable(label='Rationale')
        public String rationale;
    }

    @InvocableMethod(label='Triage Lead' description='Scores and routes a lead using AI')
    public static List<TriageResult> triageLeads(List<Id> leadIds) {
        List<TriageResult> results = new List<TriageResult>();
        List<Lead> leadsToUpdate = new List<Lead>();

        List<Lead> leads = [
            SELECT Id, Company, Industry, LeadSource, Description
            FROM Lead
            WHERE Id IN :leadIds
        ];

        for (Lead ld : leads) {
            String prompt = buildPrompt(ld);
            TriageResult result = new TriageResult();

            try {
                String rawResponse = GoogleService.callGoogle(prompt);
                Map<String, Object> parsed =
                    (Map<String, Object>) JSON.deserializeUntyped(rawResponse);

                result.priority = (String) parsed.get('priority');
                result.rationale = (String) parsed.get('rationale');

                ld.AI_Priority_Score__c = result.priority;
                ld.AI_Rationale__c = result.rationale;
                ld.AI_Last_Run__c = System.now();
                leadsToUpdate.add(ld);

            } catch (Exception e) {
                result.priority = 'Error';
                result.rationale = 'AI triage failed: ' + e.getMessage();
            }

            results.add(result);
        }

        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }

        return results;
    }

    private static String buildPrompt(Lead ld) {
        return 'You are a sales lead triage assistant. Given the lead details below, ' +
               'return ONLY valid JSON with keys "priority" (Hot, Warm, or Cold) and ' +
               '"rationale" (max 20 words). No markdown, no explanation, just the JSON object.\n\n' +
               'Company: ' + safe(ld.Company) + '\n' +
               'Industry: ' + safe(ld.Industry) + '\n' +
               'Lead Source: ' + safe(ld.LeadSource) + '\n' +
               'Description: ' + safe(ld.Description);
    }

    private static String safe(String val) {
        return String.isBlank(val) ? 'Not provided' : val;
    }
}