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
    public Map<String,String> Dimension2Map;

    // create header journal and journal lines for consulting opportunities
    public Id buildConsultingJournal(){

        String journalName  = 'Cornwall Consulting Revenue ' + StartDatetime.format('MMMMM') + ' ' + String.valueOf(StartDate.year()).substring(2,4);
        Id journalHeader    = getHeaderId(journalName);
        Id consultingId     = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Consulting').getRecordTypeId();

        // declare map of opportunity ids to corresponding journals
        List<c2g__codaJournalLineItem__c> lineItems = new List<c2g__codaJournalLineItem__c>();

        // get Opportunities of record type 'Milestone Opportunity' which have a 'Consulting' opportunity parent
        // and a CloseDate which falls inside the month
        List<MPM4_BASE__Milestone1_Milestone__c> billableMilestones =
                            [SELECT Id, MPM4_BASE__Kickoff__c, Opportunity__r.CI_Code__r.Name,
                                    Opportunity__r.CI_Code__r.Dimension3Id__c,
                                    Opportunity__r.CI_Code__c, Phase_Value_Print__c,
                                    Opportunity__r.Project_Code__c, Opportunity__r.Owner.Company__c
                            FROM MPM4_BASE__Milestone1_Milestone__c
                            WHERE MPM4_BASE__Kickoff__c >= :StartDate
                            AND MPM4_BASE__Kickoff__c < :EndDate
                            AND Opportunity__r.StageName = 'Closed Won'
                            AND Opportunity__r.RecordTypeId = :consultingId
                            AND Opportunity__r.CI_Code__c != NULL
                            AND Opportunity__r.Owner.Business_Entity__c = :CompanyName
                            AND Phase_Value_Print__c != NULL];

        // get a set of all ci codes
        Map<String,c2g__codaDimension3__c> ciCodeDimensionMap = new Map<String,c2g__codaDimension3__c>();
        List<CI_Code__c> codesToUpdate = new List<CI_Code__c>();

        for (MPM4_BASE__Milestone1_Milestone__c milestone : billableMilestones){
            if (milestone.Opportunity__r.CI_Code__r.Dimension3Id__c == null){
                ciCodeDimensionMap.put(milestone.Opportunity__r.CI_Code__c,
                        new c2g__codaDimension3__c(
                                Name                  = milestone.Opportunity__r.CI_Code__r.Name,
                                c2g__ReportingCode__c = milestone.Opportunity__r.Project_Code__c,
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

        // iterate over each billable milestone opportunity and create two journal lines, one debiting and one crediting
        for (MPM4_BASE__Milestone1_Milestone__c milestone  : billableMilestones){

            String dimension2Id = Dimension2Map.containsKey(milestone.Opportunity__r.Owner.Company__c) ?
                                  Dimension2Map.get(milestone.Opportunity__r.Owner.Company__c) : null;

            String dimension3Id = milestone.Opportunity__r.CI_Code__r.Dimension3Id__c != null ?
                                  milestone.Opportunity__r.CI_Code__r.Dimension3Id__c :
                                  ciCodeDimensionMap.get(milestone.Opportunity__r.CI_Code__c).Id;

            for (Integer x = 0; x < 2; x++){
                c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                line.c2g__Journal__c                = journalHeader;
                line.c2g__LineType__c               = 'General Ledger Account';
                line.c2g__GeneralLedgerAccount__c   = x == 0 ? workInProgressId : deferredIncomeId;
                line.c2g__Value__c                  = x == 0 ? (milestone.Phase_Value_Print__c * -1) : milestone.Phase_Value_Print__c;
                line.c2g__LineDescription__c        = journalName;
                line.c2g__DebitCredit__c            = x == 0 ? 'Credit' : 'Debit';
                line.c2g__Dimension1__c             = dimension1Id;
                line.c2g__Dimension2__c             = dimension2Id;
                line.c2g__Dimension3__c             = dimension3Id;
                lineItems.add(line);
            }

            milestone.Journal_ID__c = journalHeader;
        }

        insert lineItems;
        update billableMilestones;
        return journalHeader;
    }

    public Id buildBespokeTrainingJournal(){

        String journalName  = 'Cornwall Bespoke Training Revenue ' + StartDatetime.format('MMMMM') + ' ' + String.valueOf(StartDate.year()).substring(2,4);
        Id journalHeader    = getHeaderId(journalName);
        Id trainingId       = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Training Bespoke').getRecordTypeId();
        Id recordTypeId     = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Billable Milestone').getRecordTypeId();

        // declare map of opportunity ids to corresponding journals
        List<c2g__codaJournalLineItem__c> lineItems = new List<c2g__codaJournalLineItem__c>();

        // get Opportunities of record type 'Milestone Opportunity' which have a 'Bespoke Training' opportunity parent
        // and a CloseDate which falls inside the month
        List<Opportunity> billableMilestones =
                                [SELECT Id, CloseDate, Parent_Opportunity__r.CI_Code__r.Name,
                                        Parent_Opportunity__r.CI_Code__r.Dimension3Id__c,
                                        Parent_Opportunity__r.CI_Code__c, Amount, Total_Billable_Amount__c,
                                        Parent_Opportunity__r.Project_Code__c, Parent_Opportunity__r.Owner.Company__c,
                                        Parent_Opportunity__r.Campaign_or_Session__r.Owner.Company__c,
                                        Parent_Opportunity__r.Campaign_or_Session__r.Owner.Business_Entity__c
                                FROM Opportunity
                                WHERE StageName = 'Closed - Complete'
                                AND RecordTypeId = :recordTypeId
                                AND Parent_Opportunity__r.RecordTypeId = :trainingId
                                AND Parent_Opportunity__r.Campaign_or_Session__r.Owner.Business_Entity__c = :CompanyName
                                AND Parent_Opportunity__r.Campaign_or_Session__r.End_Date_Time__c >= :StartDate
                                AND Parent_Opportunity__r.Campaign_or_Session__r.End_Date_Time__c < :EndDate
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

        // iterate over each billable milestone opportunity and create two journal lines, one debiting and one crediting
        for (Opportunity opp : billableMilestones){

            String dimension2Id = Dimension2Map.containsKey(opp.Parent_Opportunity__r.Campaign_or_Session__r.Owner.Company__c) ?
                    Dimension2Map.get(opp.Parent_Opportunity__r.Campaign_or_Session__r.Owner.Company__c) : null;

            String dimension3Id = opp.Parent_Opportunity__r.CI_Code__r.Dimension3Id__c != null ?
                    opp.Parent_Opportunity__r.CI_Code__r.Dimension3Id__c :
                    ciCodeDimensionMap.get(opp.Parent_Opportunity__r.CI_Code__c).Id;

            for (Integer x = 0; x < 2; x++){
                c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                line.c2g__Journal__c                = journalHeader;
                line.c2g__LineType__c               = 'General Ledger Account';
                line.c2g__GeneralLedgerAccount__c   = x == 0 ? workInProgressId : deferredIncomeId;
                line.c2g__Value__c                  = x == 0 ? (opp.Amount * -1) : opp.Amount;
                line.c2g__LineDescription__c        = journalName;
                line.c2g__DebitCredit__c            = x == 0 ? 'Credit' : 'Debit';
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
                                                                Session__r.CI_Code__r.Name, Subscription_Duration__c,
                                                                Opportunity.Owner.Company__c
                                                        FROM OpportunityLineItem
                                                        WHERE Opportunity.IsClosed = TRUE
                                                        AND Opportunity.StageName != 'Closed Lost'
                                                        AND Opportunity.StageName != 'Closed - No Bid'
                                                        AND Opportunity.RecordTypeId = :publicTrainingId
                                                        AND Session__r.Owner.Business_Entity__c = :CompanyName
                                                        AND Session__r.CI_Code__c != NULL
                                                        AND Session__r.End_Date_Time__c >= :StartDate
                                                        AND Session__r.End_Date_Time__c < :EndDate
                                                        AND TotalPrice != NULL];

        // get a set of all ci codes
        Map<String,c2g__codaDimension3__c> ciCodeDimensionMap = new Map<String,c2g__codaDimension3__c>();
        Set<String> newDimensionString  = new Set<String>();
        List<CI_Code__c> codesToUpdate  = new List<CI_Code__c>();

        for (OpportunityLineItem lineItem : subscriptionItems){
            if (lineItem.Session__r.CI_Code__r.Dimension3Id__c == null){

                String dimensionString = lineItem.Product2.CI_Code__r.Name.length() > 24 ?
                        lineItem.Product2.CI_Code__r.Name.substring(0,23) :
                        lineItem.Product2.CI_Code__r.Name;

                if (!newDimensionString.contains(dimensionString)) {
                    ciCodeDimensionMap.put(lineItem.Session__r.CI_Code__c,
                            new c2g__codaDimension3__c(
                                    Name = lineItem.Session__r.CI_Code__r.Name,
                                    c2g__ReportingCode__c = lineItem.Session__r.CI_Code__r.Name.length() > 24 ?
                                            lineItem.Session__r.CI_Code__r.Name.substring(0, 23) :
                                            lineItem.Session__r.CI_Code__r.Name,
                                    CurrencyIsoCode = 'GBP'
                            ));
                }
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

        // iterate over each opportunity line item and create two journal lines, one debiting and one crediting
        for (OpportunityLineItem lineItem : subscriptionItems){

            String dimension2Id = Dimension2Map.containsKey(lineItem.Opportunity.Owner.Company__c) ?
                    Dimension2Map.get(lineItem.Opportunity.Owner.Company__c) : null;

            String dimension3Id = lineItem.Session__r.CI_Code__r.Dimension3Id__c != null ?
                    lineItem.Session__r.CI_Code__r.Dimension3Id__c :
                    ciCodeDimensionMap.get(lineItem.Session__r.CI_Code__c).Id;

            Decimal value = lineItem.TotalPrice;

            for (Integer x = 0; x < 2; x++){
                c2g__codaJournalLineItem__c line    = new c2g__codaJournalLineItem__c();
                line.c2g__Journal__c                = journalHeader;
                line.c2g__LineType__c               = 'General Ledger Account';
                line.c2g__GeneralLedgerAccount__c   = x == 0 ? salesId : deferredIncomeId;
                line.c2g__Value__c                  = x == 0 ? (value * -1) : value;
                line.c2g__LineDescription__c        = journalName;
                line.c2g__DebitCredit__c            = x == 0 ? 'Credit' : 'Debit';
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
                                                              Product2.CI_Code__r.Name, Subscription_Duration__c, ServiceDate,
                                                              Opportunity.Owner.Company__c, Product2.c2g__CODASalesRevenueAccount__c
                                                       FROM OpportunityLineItem
                                                       WHERE Opportunity.IsClosed = TRUE
                                                       AND Opportunity.StageName != 'Closed Lost'
                                                       AND Opportunity.StageName != 'Closed - No Bid'
                                                       AND Opportunity.RecordTypeId = :subscriptionId
                                                       AND Opportunity.Owner.Business_Entity__c = :CompanyName
                                                       AND ServiceDate < :EndDate
                                                       AND Product2.CI_Code__c != NULL
                                                       AND AmountRemaining__c > 0
                                                       AND TotalPrice != NULL
                                                       AND Subscription_Duration__c != NULL];

        // get a set of all ci codes
        Map<String,c2g__codaDimension3__c> ciCodeDimensionMap = new Map<String,c2g__codaDimension3__c>();
        Set<String> newDimensionString = new Set<String>();
        List<CI_Code__c> codesToUpdate = new List<CI_Code__c>();

        for (OpportunityLineItem lineItem : subscriptionItems){
            if (lineItem.Product2.CI_Code__r.Dimension3Id__c == null){

                String dimensionString = lineItem.Product2.CI_Code__r.Name.length() > 24 ?
                        lineItem.Product2.CI_Code__r.Name.substring(0,23) :
                        lineItem.Product2.CI_Code__r.Name;

                if (!newDimensionString.contains(dimensionString)){
                    ciCodeDimensionMap.put(lineItem.Product2.CI_Code__c,
                            new c2g__codaDimension3__c(
                                    Name                    = lineItem.Product2.CI_Code__r.Name,
                                    c2g__ReportingCode__c   = dimensionString,
                                    CurrencyIsoCode         = 'GBP'
                            ));
                }
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

        // iterate over each opportunity line item and create two journal lines, one debiting and one crediting
        for (OpportunityLineItem lineItem : subscriptionItems){

            if (lineItem.Product2 != null && lineItem.Product2.CI_Code__c != null
                    && lineItem.Product2.c2g__CODASalesRevenueAccount__c != null){
                String dimension2Id = Dimension2Map.containsKey(lineItem.Opportunity.Owner.Company__c) ?
                        Dimension2Map.get(lineItem.Opportunity.Owner.Company__c) : null;

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
                    line.c2g__GeneralLedgerAccount__c   = x == 0 ? lineItem.Product2.c2g__CODASalesRevenueAccount__c : deferredIncomeId;
                    line.c2g__Value__c                  = x == 0 ? (value * -1) : value;
                    line.c2g__LineDescription__c        = journalName;
                    line.c2g__DebitCredit__c            = x == 0 ? 'Credit' : 'Debit';
                    line.c2g__Dimension2__c             = dimension2Id;
                    line.c2g__Dimension3__c             = dimension3Id;
                    lineItems.add(line);
                }

                if (Label.JournalMode != 'TEST'){
                    lineItem.AmountRecognised__c += value;
                }
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

        List<c2g__codaPeriod__c> periods =
                                   [SELECT Id FROM c2g__codaPeriod__c
                                    WHERE c2g__StartDate__c = :StartDate
                                    AND c2g__EndDate__c = :EndDate.addDays(-1)
                                    AND c2g__OwnerCompany__r.Name = :CompanyName];
        List<c2g__codaAccountingCurrency__c> currencies =
                                   [SELECT Id FROM c2g__codaAccountingCurrency__c
                                    WHERE CurrencyIsoCode = 'GBP'
                                    AND c2g__OwnerCompany__r.Name = :CompanyName];

        PeriodId        = periods[0].Id;
        CurrencyId      = currencies[0].Id;
        Dimension2Map   = new Map<String,String>();

        for (c2g__codaDimension2__c company : [SELECT Id, Name FROM c2g__codaDimension2__c]){
            Dimension2Map.put(company.Name, company.Id);
        }
    }


    // constructor - default
    public JournalGenerator(String companyName){
        this.CompanyName     = companyName;
        this.StartDate       = Date.today().addMonths(-1).toStartOfMonth();
        this.EndDate         = Date.today().toStartOfMonth();
        this.StartDatetime   = Datetime.newInstance(StartDate.year(),StartDate.month(),01);
        this.doInit();
    }

    // constructor - optional date setting
    public JournalGenerator(String companyName, Integer year, Integer month){

        this.CompanyName     = companyName;
        this.StartDate       = Date.newInstance(year,month,01);
        this.EndDate         = this.StartDate.addMonths(1);
        this.StartDatetime   = Datetime.newInstance(StartDate.year(),StartDate.month(),01);

        this.doInit();
    }
}