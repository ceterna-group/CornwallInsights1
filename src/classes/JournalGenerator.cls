/**
 * Created by ronanwilliams on 2019-08-11.
 */

public class JournalGenerator {

    private Datetime StartDatetime;
    private Date StartDate;
    private Date EndDate;
    private String PeriodId;
    private String CurrencyId;
    private String CompanyName;
    public Boolean ValidParams;

    // create header journal and journal lines for consulting opportunities
    public void buildConsultingJournal(){

        String journalName  = 'Cornwall Consulting Revenue ' + StartDatetime.format('MMMMM') + ' ' + String.valueOf(StartDate.year()).substring(2,4);
        Id journalHeader    = getHeaderId(journalName);
        Id consultingId     = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Consulting').getRecordTypeId();
        Id recordTypeId     = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Milestone Opportunity').getRecordTypeId();

        // declare map of opportunity ids to corresponding journals
        List<c2g__codaJournalLineItem__c> lineItems = new List<c2g__codaJournalLineItem__c>();

        // get Opportunities of record type 'Milestone Opportunity' which have a 'Consluting' opportunity parent
        // and a CloseDate which falls inside the month
        List<Opportunity> billableMilestones =
                                    [SELECT Id, CloseDate, Parent_Opportunity__r.CI_Code__c, Amount
                                     FROM Opportunity
                                     WHERE StageName = 'Closed Won'
                                     AND RecordTypeId = :recordTypeId
                                     AND Parent_Opportunity__r.RecordTypeId = :consultingId
                                     AND CloseDate >= :StartDate
                                     AND CloseDate <= :EndDate];


        // get ids of the relevant general ledger accounts
        String workInProgressId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                   WHERE Name = '4201 - Sales - Consultancy Energy Generation - Work In Progress'].Id;
        String deferredIncomeId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                   WHERE Name = '2201 - Deferred income - Consultancy'].Id;


        // iterate over each billable milestone opportunity and create two journal lines, one debiting and one crediting
        for (Opportunity opp : billableMilestones){
            if (opp.Parent_Opportunity__r.CI_Code__c != null){
                for (Integer x = 0; x < 2; x++){
                    c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                    line.c2g__Journal__c                = journalHeader;
                    line.c2g__LineType__c               = 'General Ledger Account';
                    line.c2g__GeneralLedgerAccount__c   = x == 0 ? workInProgressId : deferredIncomeId;
                    line.c2g__Value__c                  = x == 0 ? opp.Amount : (opp.Amount * -1);
                    line.c2g__LineDescription__c        = journalName;
                    line.c2g__DebitCredit__c            = x == 0 ? 'Debit' : 'Credit';
                    lineItems.add(line);
                }

                opp.JournalId__c = journalHeader;
            }
        }

        insert lineItems;
        update billableMilestones;
    }

    public void buildBespokeTrainingJournal(){

        String journalName  = 'Cornwall Bespoke Training Revenue ' + StartDatetime.format('MMMMM') + ' ' + String.valueOf(StartDate.year()).substring(2,4);
        Id journalHeader    = getHeaderId(journalName);
        Id trainingId       = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Training Bespoke').getRecordTypeId();
        Id recordTypeId     = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Milestone Opportunity').getRecordTypeId();

        // declare map of opportunity ids to corresponding journals
        List<c2g__codaJournalLineItem__c> lineItems = new List<c2g__codaJournalLineItem__c>();

        // get Opportunities of record type 'Milestone Opportunity' which have a 'Bespoke Training' opportunity parent
        // and a CloseDate which falls inside the month
        List<Opportunity> billableMilestones =
                                [SELECT Id, CloseDate, Parent_Opportunity__r.CI_Code__c, Amount
                                FROM Opportunity
                                WHERE StageName = 'Closed Won'
                                AND RecordTypeId = :recordTypeId
                                AND Parent_Opportunity__r.RecordTypeId = :trainingId
                                AND CloseDate >= :StartDate
                                AND CloseDate <= :EndDate];

        // get ids of the relevant general ledger accounts
        String workInProgressId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
        WHERE Name = '4302 - Sales - Bespoke Training'].Id;
        String deferredIncomeId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
        WHERE Name = '2203 - Deferred Income - Bespoke Training'].Id;

        // iterate over each billable milestone opportunity and create two journal lines, one debiting and one crediting
        for (Opportunity opp : billableMilestones){
            if (opp.Parent_Opportunity__r.CI_Code__c != null){
                for (Integer x = 0; x < 2; x++){
                    c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                    line.c2g__Journal__c                = journalHeader;
                    line.c2g__LineType__c               = 'General Ledger Account';
                    line.c2g__GeneralLedgerAccount__c   = x == 0 ? workInProgressId : deferredIncomeId;
                    line.c2g__Value__c                  = x == 0 ? opp.Amount : (opp.Amount * -1);
                    line.c2g__LineDescription__c        = journalName;
                    line.c2g__DebitCredit__c            = x == 0 ? 'Debit' : 'Credit';
                    lineItems.add(line);
                }

                opp.JournalId__c = journalHeader;
            }
        }

        insert lineItems;
        update billableMilestones;
    }


    public String buildPublicTrainingJournal(){


        // i want a list of training attendees where session date falls in the last month
        // parent opp is closed won




        return null;
    }


    public String buildSubscriptionJournal(){


        // i want a list of Opportunity product lines  where record type is '')
        // and parent record type id is 'Training Bespoke'
        // and Course date falls in range (NOT CloseDate)


        return null;
    }



    private Id getHeaderId(String headerName){

        c2g__codaJournal__c journal           = new c2g__codaJournal__c();
        journal.c2g__JournalDescription__c    = headerName;
        journal.c2g__Period__c                = PeriodId;
        journal.c2g__JournalCurrency__c       = CurrencyId;

        insert journal;

        return journal.Id;
    }


    private void doInit(){

        CompanyName = c2g.CODAAPICompany_2_0.GetCurrentCompanies(null)[0];

        List<c2g__codaPeriod__c> periods =
                                   [SELECT Id FROM c2g__codaPeriod__c
                                    WHERE c2g__StartDate__c = :StartDate
                                    AND c2g__EndDate__c = :EndDate
                                    AND c2g__OwnerCompany__r.Name = :CompanyName];
        List<c2g__codaAccountingCurrency__c> currencies =
                                   [SELECT Id FROM c2g__codaAccountingCurrency__c
                                    WHERE CurrencyIsoCode = 'GBP'
                                    AND c2g__OwnerCompany__r.Name = :CompanyName];


        if (CompanyName != null && !periods.isEmpty() && !currencies.isEmpty()){
            PeriodId    = periods[0].Id;
            CurrencyId  = currencies[0].Id;
            ValidParams = true;
        } else {
            ValidParams = false;
        }
    }


    // constructor - default
    public JournalGenerator(){
        this.StartDate       = Date.today().addMonths(-1).toStartOfMonth();
        this.EndDate         = Date.today().toStartOfMonth().addDays(-1);
        this.StartDatetime   = Datetime.newInstance(StartDate.year(),StartDate.month(),01);
        this.doInit();
    }

    // constructor - optional date setting
    public JournalGenerator(Integer year, Integer month){
        this.StartDate       = Date.newInstance(year,month,01);
        this.EndDate         = this.StartDate.addMonths(1).addDays(-1);
        this.StartDatetime   = Datetime.newInstance(StartDate.year(),StartDate.month(),01);
        this.doInit();
    }
}