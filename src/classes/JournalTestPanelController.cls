/**
 * Created by ronanwilliams on 2019-08-20.
 */

public class JournalTestPanelController {

    @AuraEnabled
    public static Object generateJournalsApex(Date month){

        Map<String,Object> responseMap  = new Map<String,Object>();
        JournalGenerator generator      = new JournalGenerator(month.year(), month.month());

        if (generator.ValidParams){

            Set<Id> journalIds = new Set<Id>();
            journalIds.add(generator.buildConsultingJournal());
            journalIds.add(generator.buildBespokeTrainingJournal());
            journalIds.add(generator.buildSubscriptionJournal());
            journalIds.add(generator.buildPublicTrainingJournal());

            List<c2g__codaJournal__c> journals = [SELECT Id, Name, c2g__JournalDescription__c, c2g__Period__c
                                                    FROM c2g__codaJournal__c WHERE Id IN :journalIds];

            responseMap.put('journals',journals);
            responseMap.put('date',month);
        } else {
            responseMap.put('error','Some of the method parameters were invalid');
        }

        return responseMap;
    }
}