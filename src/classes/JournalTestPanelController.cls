/**
 * Created by ronanwilliams on 2019-08-20.
 */

public class JournalTestPanelController {

    @AuraEnabled
    public static List<Object> getUserCompanies(){

        Set<String> companies = new Set<String>();
        companies.add('Cornwall Insight Australia Pty Ltd');
        companies.add('Cornwall Insight Ireland');
        companies.add('Cornwall Insight Ltd');
        companies.add('Pixie Energy Limited');

        return [SELECT c2g__Company__r.Name
                FROM c2g__codaUserCompany__c
                WHERE c2g__User__c = :UserInfo.getUserId()
                AND c2g__Company__r.Name IN :companies];
    }

    @AuraEnabled
    public static Boolean setCurrentCompany(String companyName){
        c2g.CODAAPICompany_2_0.SetCurrentCompanies(new List<String>{companyName});
        return true;
    }

    @AuraEnabled
    public static Map<String,Object> generateJournalsApex(Date month, String companyName){

        Map<String,String> currencyMap  = new Map<String,String>();
        currencyMap.put('Cornwall Insight Australia Pty Ltd','AUD');
        currencyMap.put('Cornwall Insight Ireland','EUR');
        currencyMap.put('Cornwall Insight Ltd','GBP');
        currencyMap.put('Pixie Energy Limited','GBP');

        Map<String,Object> responseMap  = new Map<String,Object>();
        JournalGenerator generator      = new JournalGenerator(companyName,currencyMap.get(companyName),month.year(), month.month());

        if (generator.PeriodId != null && generator.CurrencyId != null){
            Set<Id> journalIds              = new Set<Id>();

            journalIds.add(generator.buildConsultingJournal());
            journalIds.add(generator.buildBespokeTrainingJournal());
            journalIds.add(generator.buildSubscriptionJournal());
            journalIds.add(generator.buildPublicTrainingJournal());

            List<c2g__codaJournal__c> journals = [SELECT Id, Name, c2g__JournalDescription__c,
                                                        c2g__Period__c, c2g__OwnerCompany__r.Name,
                                                (SELECT Id FROM c2g__JournalLineItems__r)
                                                FROM c2g__codaJournal__c WHERE Id IN :journalIds];

            responseMap.put('journals',journals);
            responseMap.put('date',month);
        } else {
            responseMap.put('error','required parameters missing');
        }


        return responseMap;
    }
}