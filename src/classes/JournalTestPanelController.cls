/**
 * Created by ronanwilliams on 2019-08-20.
 */

public class JournalTestPanelController {

    @AuraEnabled
    public static Map<String,Object> getUserCompanies(){

        Map<String,Object> responseMap = new Map<String,Object>();

        responseMap.put('companies',
                [SELECT c2g__Company__r.Name
                FROM c2g__codaUserCompany__c
                WHERE c2g__User__c = :UserInfo.getUserId()
                AND c2g__Company__r.Name IN
                        ('Cornwall Insight Australia Pty Ltd',
                        'Cornwall Insight Ireland',
                        'Cornwall Insight Ltd',
                        'Pixie Energy Limited')]);

        responseMap.put('currentCompany',c2g.CODAAPICompany_2_0.GetCurrentCompanies(new c2g.CODAAPICommon_2_0.Context()));

        return responseMap;
    }

    @AuraEnabled
    public static Object setCurrentCompany(String companyName){

        Object response = '';

        try {
            c2g.CODAAPICompany_2_0.SetCurrentCompanies(new List<String>{companyName});
            response = 'success';
        } catch (Exception e){
            response = e.getMessage();
        }

        return response;
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
            Set<Id> journalIds = new Set<Id>();

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