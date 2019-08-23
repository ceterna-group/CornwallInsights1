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
    public Id buildConsultingJournal(){

        String journalName  = 'Cornwall Consulting Revenue ' + StartDatetime.format('MMMMM') + ' ' + String.valueOf(StartDate.year()).substring(2,4);
        Id journalHeader    = getHeaderId(journalName);
        Id consultingId     = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Consulting').getRecordTypeId();
        Id recordTypeId     = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Milestone Opportunity').getRecordTypeId();

        // declare map of opportunity ids to corresponding journals
        List<c2g__codaJournalLineItem__c> lineItems = new List<c2g__codaJournalLineItem__c>();

        // get Opportunities of record type 'Milestone Opportunity' which have a 'Consulting' opportunity parent
        // and a CloseDate which falls inside the month
        List<Opportunity> billableMilestones =
                                    [SELECT Id, CloseDate, Parent_Opportunity__r.CI_Code__r.Name,
                                            Parent_Opportunity__r.CI_Code__r.Dimension3Id__c,
                                            Parent_Opportunity__r.CI_Code__c, Amount, Invoice_Amount__c,
                                            Parent_Opportunity__r.Project_Code__c
                                     FROM Opportunity
                                     WHERE StageName = 'Closed - Complete'
                                     AND RecordTypeId = :recordTypeId
                                     AND Parent_Opportunity__r.RecordTypeId = :consultingId
                                     AND Parent_Opportunity__r.CI_Code__c != NULL
                                     AND CloseDate >= :StartDate
                                     AND CloseDate <= :EndDate
                                     AND Invoice_Amount__c != NULL];

        // get a set of all ci codes
        Map<String,c2g__codaDimension3__c> ciCodeDimensionMap = new Map<String,c2g__codaDimension3__c>();
        List<CI_Code__c> codesToUpdate = new List<CI_Code__c>();

        for (Opportunity opp : billableMilestones){
            if (opp.Parent_Opportunity__r.CI_Code__r.Dimension3Id__c == null){
                ciCodeDimensionMap.put(opp.Parent_Opportunity__r.CI_Code__c,
                        new c2g__codaDimension3__c(
                                Name                  = opp.Parent_Opportunity__r.CI_Code__r.Name,
                                c2g__ReportingCode__c = opp.Parent_Opportunity__r.Project_Code__c,
                                CurrencyIsoCode       = 'GBP'
                ));
            }
        }

        insert ciCodeDimensionMap.values();

        for (String ciCodeId : ciCodeDimensionMap.keySet()){
            codesToUpdate.add(new CI_Code__c(
                Id = ciCodeId,
                Dimension_3__c = ciCodeDimensionMap.get(ciCodeId).Id
            ));
        }

        update codesToUpdate;

        // get ids of the relevant general ledger accounts
        String workInProgressId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                   WHERE Name = '4201 - Sales - Consultancy Energy Generation - Work In Progress'].Id;
        String deferredIncomeId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                   WHERE Name = '2201 - Deferred income - Consultancy'].Id;
        String dimension1Id     = [SELECT Id FROM c2g__codaDimension1__c WHERE Name = 'Consultancy' LIMIT 1].Id;
        String dimension2Id     = [SELECT Id FROM c2g__codaDimension2__c WHERE Name = 'London' LIMIT 1].Id;

        // iterate over each billable milestone opportunity and create two journal lines, one debiting and one crediting
        for (Opportunity opp : billableMilestones){

            String dimension3Id = opp.Parent_Opportunity__r.CI_Code__r.Dimension3Id__c != null ?
                                  opp.Parent_Opportunity__r.CI_Code__r.Dimension3Id__c :
                                  ciCodeDimensionMap.get(opp.Parent_Opportunity__r.CI_Code__c).Id;

            for (Integer x = 0; x < 2; x++){
                c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                line.c2g__Journal__c                = journalHeader;
                line.c2g__LineType__c               = 'General Ledger Account';
                line.c2g__GeneralLedgerAccount__c   = x == 0 ? workInProgressId : deferredIncomeId;
                line.c2g__Value__c                  = x == 0 ? opp.Invoice_Amount__c : (opp.Invoice_Amount__c * -1);
                line.c2g__LineDescription__c        = journalName;
                line.c2g__DebitCredit__c            = x == 0 ? 'Debit' : 'Credit';
                line.c2g__Dimension1__c             = dimension1Id;
                line.c2g__Dimension2__c             = dimension2Id;
                line.c2g__Dimension3__c             = dimension3Id;
                lineItems.add(line);
            }

            opp.JournalId__c = journalHeader;
        }

        insert lineItems;
        update billableMilestones;
        return journalHeader;
    }

    public Id buildBespokeTrainingJournal(){

        String journalName  = 'Cornwall Bespoke Training Revenue ' + StartDatetime.format('MMMMM') + ' ' + String.valueOf(StartDate.year()).substring(2,4);
        Id journalHeader    = getHeaderId(journalName);
        Id trainingId       = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Training Bespoke').getRecordTypeId();
        Id recordTypeId     = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Milestone Opportunity').getRecordTypeId();

        // declare map of opportunity ids to corresponding journals
        List<c2g__codaJournalLineItem__c> lineItems = new List<c2g__codaJournalLineItem__c>();

        // get Opportunities of record type 'Milestone Opportunity' which have a 'Bespoke Training' opportunity parent
        // and a CloseDate which falls inside the month
        List<Opportunity> billableMilestones =
                                [SELECT Id, CloseDate, Parent_Opportunity__r.CI_Code__r.Name,
                                        Parent_Opportunity__r.CI_Code__r.Dimension3Id__c,
                                        Parent_Opportunity__r.CI_Code__c, Amount, Total_Billable_Amount__c,
                                        Parent_Opportunity__r.Project_Code__c
                                FROM Opportunity
                                WHERE StageName = 'Closed - Complete'
                                AND RecordTypeId = :recordTypeId
                                AND Parent_Opportunity__r.RecordTypeId = :trainingId
                                AND CloseDate >= :StartDate
                                AND CloseDate <= :EndDate
                                AND Amount != NULL];

        // get a set of all ci codes
        Map<String,c2g__codaDimension3__c> ciCodeDimensionMap = new Map<String,c2g__codaDimension3__c>();
        List<CI_Code__c> codesToUpdate = new List<CI_Code__c>();

        for (Opportunity opp : billableMilestones){
            if (opp.Parent_Opportunity__r.CI_Code__r.Dimension3Id__c == null){
                ciCodeDimensionMap.put(opp.Parent_Opportunity__r.CI_Code__c,
                    new c2g__codaDimension3__c(
                        Name                    = opp.Parent_Opportunity__r.CI_Code__r.Name,
                        c2g__ReportingCode__c   = opp.Parent_Opportunity__r.Project_Code__c,
                        CurrencyIsoCode         = 'GBP'
                    ));
            }
        }

        insert ciCodeDimensionMap.values();

        for (String ciCodeId : ciCodeDimensionMap.keySet()){
            codesToUpdate.add(new CI_Code__c(
                    Id              = ciCodeId,
                    Dimension_3__c  = ciCodeDimensionMap.get(ciCodeId).Id
            ));
        }

        update codesToUpdate;

        // get ids of the relevant general ledger accounts
        String workInProgressId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                    WHERE Name = '4302 - Sales - Bespoke Training'].Id;
        String deferredIncomeId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                    WHERE Name = '2203 - Deferred Income - Bespoke Training'].Id;
        String dimension1Id     = [SELECT Id FROM c2g__codaDimension1__c WHERE Name = 'Training' LIMIT 1].Id;
        String dimension2Id     = [SELECT Id FROM c2g__codaDimension2__c WHERE Name = 'London' LIMIT 1].Id;

        // iterate over each billable milestone opportunity and create two journal lines, one debiting and one crediting
        for (Opportunity opp : billableMilestones){
            String dimension3Id = opp.Parent_Opportunity__r.CI_Code__r.Dimension3Id__c != null ?
                    opp.Parent_Opportunity__r.CI_Code__r.Dimension3Id__c :
                    ciCodeDimensionMap.get(opp.Parent_Opportunity__r.CI_Code__c).Id;

            for (Integer x = 0; x < 2; x++){
                c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                line.c2g__Journal__c                = journalHeader;
                line.c2g__LineType__c               = 'General Ledger Account';
                line.c2g__GeneralLedgerAccount__c   = x == 0 ? workInProgressId : deferredIncomeId;
                line.c2g__Value__c                  = x == 0 ? opp.Total_Billable_Amount__c : (opp.Total_Billable_Amount__c * -1);
                line.c2g__LineDescription__c        = journalName;
                line.c2g__DebitCredit__c            = x == 0 ? 'Debit' : 'Credit';
                line.c2g__Dimension1__c             = dimension1Id;
                line.c2g__Dimension2__c             = dimension2Id;
                line.c2g__Dimension3__c             = dimension3Id;
                lineItems.add(line);
            }

            opp.JournalId__c = journalHeader;
        }

        insert lineItems;
        update billableMilestones;
        return journalHeader;

    }


    public String buildPublicTrainingJournal(){

        String journalName  = 'Cornwall Public Training Revenue ' + StartDatetime.format('MMMMM') + ' ' + String.valueOf(StartDate.year()).substring(2,4);
        Id journalHeader    = getHeaderId(journalName);
        Id publicTrainingId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Training Public').getRecordTypeId();

        // declare map of opportunity ids to corresponding journals
        List<c2g__codaJournalLineItem__c> lineItems = new List<c2g__codaJournalLineItem__c>();


        List<OpportunityLineItem> subscriptionItems = [SELECT Id, TotalPrice, Session__r.CI_Code__c,
                                                                Session__r.CI_Code__r.Dimension3Id__c,
                                                                Session__r.CI_Code__r.Name, Subscription_Duration__c
                                                        FROM OpportunityLineItem
                                                        WHERE Opportunity.IsClosed = TRUE
                                                        AND Opportunity.StageName != 'Closed Lost'
                                                        AND Opportunity.StageName != 'Closed - No Bid'
                                                        AND Opportunity.RecordTypeId = :publicTrainingId
                                                        AND Session__r.CI_Code__c != NULL
                                                        AND Session__r.End_Date_Time__c >= :StartDate
                                                        AND Session__r.End_Date_Time__c <= :EndDate
                                                        AND TotalPrice != NULL];


        System.debug('records found is ' + subscriptionItems.size());

        // get a set of all ci codes
        Map<String,c2g__codaDimension3__c> ciCodeDimensionMap = new Map<String,c2g__codaDimension3__c>();
        List<CI_Code__c> codesToUpdate  = new List<CI_Code__c>();

        for (OpportunityLineItem lineItem : subscriptionItems){
            if (lineItem.Session__r.CI_Code__r.Dimension3Id__c == null){
                ciCodeDimensionMap.put(lineItem.Session__r.CI_Code__c,
                        new c2g__codaDimension3__c(
                                Name                    = lineItem.Session__r.CI_Code__r.Name,
                                c2g__ReportingCode__c   = lineItem.Session__r.CI_Code__r.Name.length() > 24 ?
                                        lineItem.Session__r.CI_Code__r.Name.substring(0,23) :
                                        lineItem.Session__r.CI_Code__r.Name,
                                CurrencyIsoCode         = 'GBP'
                        ));
            }
        }

        insert ciCodeDimensionMap.values();

        for (String ciCodeId : ciCodeDimensionMap.keySet()){
            codesToUpdate.add(new CI_Code__c(
                    Id              = ciCodeId,
                    Dimension_3__c  = ciCodeDimensionMap.get(ciCodeId).Id
            ));
        }

        update codesToUpdate;

        // get ids of the relevant general ledger accounts
        String salesId          = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                    WHERE Name = '4300 - Sales - Public Training'].Id;
        String deferredIncomeId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                    WHERE Name = '2202 - Deferred Income - Public Training'].Id;
        String dimension1Id     = [SELECT Id FROM c2g__codaDimension1__c WHERE Name = 'Training' LIMIT 1].Id;
        String dimension2Id     = [SELECT Id FROM c2g__codaDimension2__c WHERE Name = 'London' LIMIT 1].Id;

        // iterate over each opportunity line item and create two journal lines, one debiting and one crediting
        for (OpportunityLineItem lineItem : subscriptionItems){
            String dimension3Id = lineItem.Session__r.CI_Code__r.Dimension3Id__c != null ?
                    lineItem.Session__r.CI_Code__r.Dimension3Id__c :
                    ciCodeDimensionMap.get(lineItem.Session__r.CI_Code__c).Id;

            Decimal value = lineItem.TotalPrice;

            for (Integer x = 0; x < 2; x++){
                c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                line.c2g__Journal__c                = journalHeader;
                line.c2g__LineType__c               = 'General Ledger Account';
                line.c2g__GeneralLedgerAccount__c   = x == 0 ? salesId : deferredIncomeId;
                line.c2g__Value__c                  = x == 0 ? value : (value * -1);
                line.c2g__LineDescription__c        = journalName;
                line.c2g__DebitCredit__c            = x == 0 ? 'Debit' : 'Credit';
                line.c2g__Dimension1__c             = dimension1Id;
                line.c2g__Dimension2__c             = dimension2Id;
                line.c2g__Dimension3__c             = dimension3Id;
                lineItems.add(line);
            }

            lineItem.JournalId__c = journalHeader;
        }

        insert lineItems;
        update subscriptionItems;

        return journalHeader;


    }


    public String buildSubscriptionJournal(){


        String journalName  = 'Cornwall Subscription Revenue ' + StartDatetime.format('MMMMM') + ' ' + String.valueOf(StartDate.year()).substring(2,4);
        Id journalHeader    = getHeaderId(journalName);
        Id subscriptionId   = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Core').getRecordTypeId();

        // declare map of opportunity ids to corresponding journals
        List<c2g__codaJournalLineItem__c> lineItems = new List<c2g__codaJournalLineItem__c>();


        List<OpportunityLineItem> subscriptionItems = [SELECT Id, TotalPrice, AmountRecognised__c, AmountRemaining__c,
                                                              Product2.CI_Code__c, Product2.CI_Code__r.Dimension3Id__c,
                                                              Product2.CI_Code__r.Name, Subscription_Duration__c, ServiceDate
                                                       FROM OpportunityLineItem
                                                       WHERE Opportunity.IsClosed = TRUE
                                                       AND Opportunity.StageName != 'Closed Lost'
                                                       AND Opportunity.StageName != 'Closed - No Bid'
                                                       AND Opportunity.RecordTypeId = :subscriptionId
                                                       AND ServiceDate <= :EndDate
                                                       AND Product2.CI_Code__c != NULL
                                                       AND AmountRemaining__c > 0
                                                       AND TotalPrice != NULL
                                                       AND Subscription_Duration__c != NULL];

        // get a set of all ci codes
        Map<String,c2g__codaDimension3__c> ciCodeDimensionMap = new Map<String,c2g__codaDimension3__c>();
        List<CI_Code__c> codesToUpdate = new List<CI_Code__c>();

        for (OpportunityLineItem lineItem : subscriptionItems){
            if (lineItem.Product2.CI_Code__r.Dimension3Id__c == null){
                ciCodeDimensionMap.put(lineItem.Product2.CI_Code__c,
                        new c2g__codaDimension3__c(
                                Name                    = lineItem.Product2.CI_Code__r.Name,
                                c2g__ReportingCode__c   = lineItem.Product2.CI_Code__r.Name.length() > 24 ?
                                                          lineItem.Product2.CI_Code__r.Name.substring(0,23) :
                                                          lineItem.Product2.CI_Code__r.Name,
                                CurrencyIsoCode         = 'GBP'
                        ));
            }
        }

        insert ciCodeDimensionMap.values();

        for (String ciCodeId : ciCodeDimensionMap.keySet()){
            codesToUpdate.add(new CI_Code__c(
                    Id              = ciCodeId,
                    Dimension_3__c  = ciCodeDimensionMap.get(ciCodeId).Id
            ));
        }

        update codesToUpdate;

        // get ids of the relevant general ledger accounts
        String salesId          = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                    WHERE Name = '4000 - Sales - Energy Spectrum - Single User'].Id;
        String deferredIncomeId = [SELECT Id FROM c2g__codaGeneralLedgerAccount__c
                                    WHERE Name = '2200 - Deferred Income - Subscriptions'].Id;
        String dimension2Id     = [SELECT Id FROM c2g__codaDimension2__c WHERE Name = 'London' LIMIT 1].Id;

        // iterate over each opportunity line item and create two journal lines, one debiting and one crediting
        for (OpportunityLineItem lineItem : subscriptionItems){
            String dimension3Id = lineItem.Product2.CI_Code__r.Dimension3Id__c != null ?
                    lineItem.Product2.CI_Code__r.Dimension3Id__c :
                    ciCodeDimensionMap.get(lineItem.Product2.CI_Code__c).Id;

            Decimal value = (lineItem.TotalPrice / lineItem.Subscription_Duration__c).setScale(2);

            if (lineItem.AmountRecognised__c == null){
                lineItem.AmountRecognised__c = 0;
            }

            for (Integer x = 0; x < 2; x++){
                c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                line.c2g__Journal__c                = journalHeader;
                line.c2g__LineType__c               = 'General Ledger Account';
                line.c2g__GeneralLedgerAccount__c   = x == 0 ? salesId : deferredIncomeId;
                line.c2g__Value__c                  = x == 0 ? value : (value * -1);
                line.c2g__LineDescription__c        = journalName;
                line.c2g__DebitCredit__c            = x == 0 ? 'Debit' : 'Credit';
                line.c2g__Dimension2__c             = dimension2Id;
                line.c2g__Dimension3__c             = dimension3Id;
                lineItems.add(line);
            }

            if (Label.JournalMode != 'TEST'){
                lineItem.AmountRecognised__c += value;
            }

        }

        insert lineItems;
        update subscriptionItems;

        return journalHeader;
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