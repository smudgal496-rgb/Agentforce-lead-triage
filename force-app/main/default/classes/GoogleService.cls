public with sharing class GoogleService {

    public class GoogleCalloutException extends Exception {}

    public static String callGoogle(String userPrompt) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Google_API/v1beta/models/gemini-3-flash-preview:generateContent');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(60000);

        Map<String, Object> body = new Map<String, Object>{
            'contents' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'parts' => new List<Map<String, Object>>{
                        new Map<String, Object>{ 'text' => userPrompt }
                    }
                }
            }
        };
        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res;

        try {
            res = http.send(req);
        } catch (Exception e) {
            throw new GoogleCalloutException('Callout failed: ' + e.getMessage());
        }

        if (res.getStatusCode() != 200) {
            throw new GoogleCalloutException(
                'Gemini API returned ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        List<Object> candidates = (List<Object>) responseMap.get('candidates');
        if (candidates == null || candidates.isEmpty()) {
            throw new GoogleCalloutException('Empty response from Gemini API');
        }

        Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
        Map<String, Object> content = (Map<String, Object>) firstCandidate.get('content');
        List<Object> parts = (List<Object>) content.get('parts');
        Map<String, Object> firstPart = (Map<String, Object>) parts[0];

        return (String) firstPart.get('text');
    }
}