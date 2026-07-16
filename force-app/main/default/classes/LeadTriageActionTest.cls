@isTest
private class LeadTriageActionTest {

    private class MockGoogleResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');

            String fakeGoogleBody = '{"candidates":[{"content":{"parts":[{"text":"{\\"priority\\":\\"Hot\\",\\"rationale\\":\\"Enterprise company with strong buying signals\\"}"}]}}]}';
            res.setBody(fakeGoogleBody);
            return res;
        }
    }

    @isTest
    static void testTriageLeadSuccess() {
        Lead testLead = new Lead(
            LastName = 'Test Lead',
            Company = 'Acme Corp',
            Industry = 'Technology',
            LeadSource = 'Web',
            Description = 'Large enterprise, requested demo, 500+ employees'
        );
        insert testLead;

        Test.setMock(HttpCalloutMock.class, new MockGoogleResponse());

        Test.startTest();
        List<LeadTriageAction.TriageResult> results =
            LeadTriageAction.triageLeads(new List<Id>{ testLead.Id });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals('Hot', results[0].priority, 'Priority should be Hot');

        Lead updatedLead = [
            SELECT AI_Priority_Score__c, AI_Rationale__c, AI_Last_Run__c
            FROM Lead
            WHERE Id = :testLead.Id
        ];
        System.assertEquals('Hot', updatedLead.AI_Priority_Score__c);
        System.assertNotEquals(null, updatedLead.AI_Last_Run__c);
    }

    private class MockGoogleError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    @isTest
    static void testTriageLeadHandlesFailureGracefully() {
        Lead testLead = new Lead(
            LastName = 'Fail Test',
            Company = 'Broken Co'
        );
        insert testLead;

        Test.setMock(HttpCalloutMock.class, new MockGoogleError());

        Test.startTest();
        List<LeadTriageAction.TriageResult> results =
            LeadTriageAction.triageLeads(new List<Id>{ testLead.Id });
        Test.stopTest();

        System.assertEquals('Error', results[0].priority, 'Should mark as Error on failure');
    }
}