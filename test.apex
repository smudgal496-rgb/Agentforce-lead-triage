List<Id> testIds = new List<Id>{ [SELECT Id FROM Lead WHERE LastName = 'Test Lead' LIMIT 1].Id };
List<LeadTriageAction.TriageResult> results = LeadTriageAction.triageLeads(testIds);
System.debug('Priority: ' + results[0].priority);
System.debug('Rationale: ' + results[0].rationale);