/**
 * Created by ronanwilliams on 2019-09-23.
 */

@IsTest
public class JournalGeneratorTest {

    @TestSetup
    public static void doTestSetup(){

        // insert user
        Profile profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User user = new User(
                LastName            = 'Test',
                FirstName           = 'Test',
                Alias               = 'ttest',
                Email               = 'test@test.com',
                Username            = 'test@test.com',
                ProfileId           = profileId.Id,
                TimeZoneSidKey      = 'GMT',
                LanguageLocaleKey   = 'en_US',
                EmailEncodingKey    = 'UTF-8',
                LocaleSidKey        = 'en_US'
        );

        // insert financial force companies

        List<c2g__codaCompany__c> companies = new List<c2g__codaCompany__c>();
        companies.add(new c2g__codaCompany__c(Name = 'Cornwall Insight Australia Pty Ltd'));
        companies.add(new c2g__codaCompany__c(Name = 'Cornwall Insight Ireland'));
        companies.add(new c2g__codaCompany__c(Name = 'Cornwall Insight Ltd'));
        companies.add(new c2g__codaCompany__c(Name = 'Pixie Energy Limited'));
        insert companies;

        // insert user companies
        List<c2g__codaUserCompany__c> userCompanies = new List<c2g__codaUserCompany__c>();
        for (c2g__codaCompany__c company : companies){
            userCompanies.add(new c2g__codaUserCompany__c(c2g__User__c = user.Id, c2g__Company__c = company.Id));
        }

        insert userCompanies;

//        Set<String> companies = new Set<String>();
//        companies.add('Cornwall Insight Australia Pty Ltd');
//        companies.add('Cornwall Insight Ireland');
//        companies.add('Cornwall Insight Ltd');
//        companies.add('Pixie Energy Limited');
//
//        return [SELECT c2g__Company__r.Name
//        FROM c2g__codaUserCompany__c
//        WHERE c2g__User__c = :UserInfo.getUserId()
//        AND c2g__Company__r.Name IN :companies];
//

        // insert consulting opps


        // insert subscription opps


        // insert bespoke training


        // insert public training



    }

    @IsTest
    public static void testOne(){

    }



}