/**
 * Created by ronanwilliams on 2019-09-23.
 */

@IsTest
public class JournalGeneratorTest {

    @TestSetup
    public static void createTransaction() {
        // Setup Company and User association within runAs to avoid mixed DML restriction
        Group companyGroup = null;

        System.runAs([SELECT Id FROM User WHERE Id = :UserInfo.getUserId()][0]) {

            Test.startTest();
            update new User(
                Id = UserInfo.getUserId(),
                Business_Entity__c = 'Cornwall Insight Australia Pty Ltd'
            );

            // Create Company
            c2g__codaCompany__c company = new c2g__codaCompany__c();
            company.Name                = 'Cornwall Insight Australia Pty Ltd';
            company.RecordTypeId        = Schema.SObjectType.c2g__codaCompany__c.recordTypeInfosByName.get('VAT').recordTypeId;
            insert company;

            // Create Company Queue
            c2g.CODACompanyWebService.createQueue(company.Id, 'GBP', 'FF' + company.Name);

            // Activate the Company
            c2g.CODAYearWebService.calculatePeriods(null); // Workaround to bug in company API's, safe to remain once fixed
            c2g.CODACompanyWebService.activateCompany(company.Id, 'GBP', company.Name);

            // Assign the User to the Company
            c2g__codaUserCompany__c userCompany = new c2g__codaUserCompany__c();
            userCompany.c2g__Company__c         = company.Id;
            userCompany.c2g__User__c            = UserInfo.getUserId();
            insert userCompany;

            // Assign the User to the Company Queue
            String queueName    = 'FF ' + company.Name;
            companyGroup        = [SELECT Id FROM Group WHERE Name = :queueName AND Type = 'Queue'];
            insert new GroupMember(GroupId = companyGroup.Id, UserOrGroupId = UserInfo.getUserId());

            Test.stopTest();
        }

        // Assert user logged into the company
        System.assertEquals('Cornwall Insight Australia Pty Ltd', c2g.CODAAPICompany_2_0.GetCurrentCompanies(null)[0]);

        // Create Year and Periods
        c2g__codaYear__c yr         = new c2g__codaYear__c();
        yr.Name                     = String.valueOf(Date.today().year());
        yr.OwnerId                  = companyGroup.Id;
        yr.c2g__NumberOfPeriods__c  = 12;
        yr.c2g__AutomaticPeriodList__c = true;
        yr.c2g__StartDate__c        = Date.valueOf(Date.today().year() + '-01-01 00:00:00');
        yr.c2g__EndDate__c          = Date.valueOf(Date.today().year() + '-12-31 00:00:00');
        yr.c2g__PeriodCalculationBasis__c = 'Month End';
        insert yr;
        c2g.CODAYearWebService.calculatePeriods(yr.Id);

        // Create Accounting Currency
        if (UserInfo.isMultiCurrencyOrganization()) {
            c2g__codaAccountingCurrency__c testCurrency = new c2g__codaAccountingCurrency__c();
            testCurrency.Name                   = 'GBP';
            testCurrency.c2g__DecimalPlaces__c  = 2;
            testCurrency.c2g__Home__c           = true;
            testCurrency.c2g__Dual__c           = true;
            insert testCurrency;
        }

        // Create General Ledger Accounts
        List<c2g__codaGeneralLedgerAccount__c> generalLedgerAccounts = new List<c2g__codaGeneralLedgerAccount__c>();
        generalLedgerAccounts.add(new c2g__codaGeneralLedgerAccount__c(
                Name                    = '4201 - Sales - Consultancy Energy Generation - Work In Progress',
                c2g__ReportingCode__c   = '101',
                c2g__Type__c            = 'Profit and Loss'
        ));
        generalLedgerAccounts.add(new c2g__codaGeneralLedgerAccount__c(
                Name                    = '2201 - Deferred income - Consultancy',
                c2g__ReportingCode__c   = '102',
                c2g__Type__c            = 'Balance Sheet'
        ));
        generalLedgerAccounts.add(new c2g__codaGeneralLedgerAccount__c(
                Name                    = '4302 - Sales - Bespoke Training',
                c2g__ReportingCode__c   = '103',
                c2g__Type__c            = 'Profit and Loss'
        ));
        generalLedgerAccounts.add(new c2g__codaGeneralLedgerAccount__c(
                Name                    = '2203 - Deferred Income - Bespoke Training',
                c2g__ReportingCode__c   = '104',
                c2g__Type__c            = 'Balance Sheet'
        ));
        generalLedgerAccounts.add(new c2g__codaGeneralLedgerAccount__c(
                Name                    = '4300 - Sales - Public Training',
                c2g__ReportingCode__c   = '105',
                c2g__Type__c            = 'Profit and Loss'
        ));
        generalLedgerAccounts.add(new c2g__codaGeneralLedgerAccount__c(
                Name                    = '2202 - Deferred Income - Public Training',
                c2g__ReportingCode__c   = '106',
                c2g__Type__c            = 'Balance Sheet'
        ));
        generalLedgerAccounts.add(new c2g__codaGeneralLedgerAccount__c(
                Name                    = '4000 - Sales - Energy Spectrum - Single User',
                c2g__ReportingCode__c   = '107',
                c2g__Type__c            = 'Profit and Loss'
        ));
        generalLedgerAccounts.add(new c2g__codaGeneralLedgerAccount__c(
                Name                    = '2200 - Deferred Income - Subscriptions',
                c2g__ReportingCode__c   = '108',
                c2g__Type__c            = 'Balance Sheet'
        ));
        insert generalLedgerAccounts;

        // create dimension1 records
        List<c2g__codaDimension1__c> dimension1s = new List<c2g__codaDimension1__c>();
        dimension1s.add(new c2g__codaDimension1__c(Name = 'Consultancy',c2g__ReportingCode__c = '1'));
        dimension1s.add(new c2g__codaDimension1__c(Name = 'Training',c2g__ReportingCode__c = '2'));
        insert dimension1s;

        // insert account
        Account account = new Account();
        account.Name    = 'Test';
        insert account;

        // create consulting opp
        Opportunity consultingOpp       = new Opportunity();
        consultingOpp.AccountId         = account.Id;
        consultingOpp.Name              = 'Consulting Opportunity';
        consultingOpp.StageName         = 'Closed Won';
        consultingOpp.CloseDate         = Date.today();
        consultingOpp.RecordTypeId      = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Consulting').getRecordTypeId();
        insert consultingOpp;

        MPM4_BASE__Milestone1_Milestone__c mileStone = new MPM4_BASE__Milestone1_Milestone__c();
        mileStone.Opportunity__c        = consultingOpp.Id;
        mileStone.MPM4_BASE__Kickoff__c = Date.today().toStartOfMonth();
        mileStone.Phase_Value_Print__c  = 100;
        insert mileStone;

        // create bespoke training opp
        Campaign bespokeTrainingCamp    = new Campaign();
        bespokeTrainingCamp.Name        = 'Bespoke Training Session';
        bespokeTrainingCamp.End_Date_Time__c = Datetime.now();
        insert bespokeTrainingCamp;

        Opportunity bespokeTrainingOpp  = new Opportunity();
        bespokeTrainingOpp.AccountId    = account.Id;
        bespokeTrainingOpp.Name         = 'Bespoke Training Opportunity';
        bespokeTrainingOpp.Amount       = 100;
        bespokeTrainingOpp.StageName    = 'Closed Won';
        bespokeTrainingOpp.CloseDate    = Date.today();
        bespokeTrainingOpp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Training Bespoke').getRecordTypeId();
        bespokeTrainingOpp.Campaign_or_Session__c = bespokeTrainingCamp.Id;
        insert bespokeTrainingOpp;

        Opportunity bespokeMilestoneOpp = new Opportunity();
        bespokeMilestoneOpp.AccountId   = account.Id;
        bespokeMilestoneOpp.Name        = 'Bespoke Training Opportunity';
        bespokeMilestoneOpp.Amount      = 100;
        bespokeMilestoneOpp.StageName   = 'Closed - Complete';
        bespokeMilestoneOpp.CloseDate   = Date.today();
        bespokeMilestoneOpp.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Milestone Opportunity').getRecordTypeId();
        bespokeMilestoneOpp.Parent_Opportunity__c = bespokeTrainingOpp.Id;
        insert bespokeMilestoneOpp;

        // create public training opp
        Campaign publicTrainingCamp     = new Campaign();
        publicTrainingCamp.Name         = 'Public Training Session';
        publicTrainingCamp.End_Date_Time__c = Datetime.now();
        insert publicTrainingCamp;

        Opportunity publicTrainingOpp   = new Opportunity();
        publicTrainingOpp.AccountId     = account.Id;
        publicTrainingOpp.Name          = 'Public Training Opportunity';
        publicTrainingOpp.StageName     = 'Closed Won';
        publicTrainingOpp.CloseDate     = Date.today();
        publicTrainingOpp.RecordTypeId  = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Training Public').getRecordTypeId();
        publicTrainingOpp.Campaign_or_Session__c = bespokeTrainingCamp.Id;
        insert publicTrainingOpp;

        Product2 publicTrainingProduct  = new Product2();
        publicTrainingProduct.Name      = 'Public Training Product';
        insert publicTrainingProduct;

        PricebookEntry publicTrainingEntry = new PricebookEntry();
        publicTrainingEntry.Pricebook2Id = Test.getStandardPricebookId();
        publicTrainingEntry.UnitPrice    = 100;
        publicTrainingEntry.Product2Id   = publicTrainingProduct.Id;
        publicTrainingEntry.IsActive     = true;
        insert publicTrainingEntry;

        OpportunityLineItem publicLineItem = new OpportunityLineItem();
        publicLineItem.UnitPrice        = 100;
        publicLineItem.Quantity         = 10;
        publicLineItem.OpportunityId    = publicTrainingOpp.Id;
        publicLineItem.Subscription_Duration__c = 12;
        publicLineItem.Session__c       = publicTrainingCamp.Id;
        publicLineItem.PricebookEntryId = publicTrainingEntry.Id;
        insert publicLineItem;


        System.debug([SELECT Id,UnitPrice, TotalPrice FROM OpportunityLineItem WHERE Id = :publicLineItem.Id]);


        // create subscription opp
        Opportunity subscriptionOpp     = new Opportunity();
        subscriptionOpp.AccountId       = account.Id;
        subscriptionOpp.Name            = 'Public Training Opportunity';
        subscriptionOpp.StageName       = 'Closed Won';
        subscriptionOpp.CloseDate       = Date.today();
        subscriptionOpp.RecordTypeId    = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Core').getRecordTypeId();
        subscriptionOpp.Campaign_or_Session__c = bespokeTrainingCamp.Id;
        insert subscriptionOpp;

        Product2 subscriptionProduct     = new Product2();
        subscriptionProduct.Name         = 'Subscription Product';
        insert subscriptionProduct;

        PricebookEntry subscriptionEntry = new PricebookEntry();
        subscriptionEntry.Pricebook2Id = Test.getStandardPricebookId();
        subscriptionEntry.UnitPrice    = 100;
        subscriptionEntry.Product2Id   = subscriptionProduct.Id;
        subscriptionEntry.IsActive     = true;
        insert subscriptionEntry;

        OpportunityLineItem subscriptionLineItem = new OpportunityLineItem();
        subscriptionLineItem.UnitPrice  = 100;
        subscriptionLineItem.Quantity   = 10;
        subscriptionLineItem.OpportunityId = subscriptionOpp.Id;
        subscriptionLineItem.Subscription_Duration__c = 12;
        subscriptionLineItem.ServiceDate = Date.today();
        subscriptionLineItem.PricebookEntryId = subscriptionEntry.Id;
        insert subscriptionLineItem;

    }

    @IsTest
    public static void testGetSetCurrentCompanies(){

        System.assertEquals(1,JournalTestPanelController.getUserCompanies().size());
        System.assertEquals(true,JournalTestPanelController.setCurrentCompany('Cornwall Insight Australia Pty Ltd'));

    }

    @IsTest
    public static void testGenerateJournals(){

        JournalTestPanelController.generateJournalsApex(Date.today(), 'Cornwall Insight Australia Pty Ltd');

    }



}