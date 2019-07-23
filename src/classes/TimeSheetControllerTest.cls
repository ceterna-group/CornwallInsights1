/**
 * Created by ronanwilliams on 2019-07-22.
 */

@IsTest
public class TimeSheetControllerTest {

    // data setup
    @TestSetup
    public static void doSetup(){

        // create CI Code records
        List<CI_Code__c> codes = new List<CI_Code__c>();

        // sample with no billing allowed
        codes.add(new CI_Code__c(Name = 'Sickness', Non_Billable__c = true));

        // sample with billing allowed
        codes.add(new CI_Code__c(Name = 'Business Development', Non_Billable__c = false));

        // sample project records
        codes.add(new CI_Code__c(Name = 'Sample project 1', Non_Billable__c = false));
        codes.add(new CI_Code__c(Name = 'Sample project 2', Non_Billable__c = false));
        codes.add(new CI_Code__c(Name = 'Sample project 3', Non_Billable__c = false));
        codes.add(new CI_Code__c(Name = 'Sample project 4', Non_Billable__c = false));

        insert codes;

        // create two time sheet records, the first dated to the Monday of the week prior
        // and the second dated to the Monday of the current week
        Time_Sheet__c sheet1    = new Time_Sheet__c();
        sheet1.Week__c          = Date.today().toStartOfWeek().addDays(-7);
        sheet1.Department__c    = 'Wholesale';
        insert sheet1;

        Time_Sheet__c sheet2    = new Time_Sheet__c();
        sheet2.Week__c          = Date.today().toStartOfWeek();
        sheet2.Department__c    = 'Wholesale';
        insert sheet2;

        // add sample time sheet entries
        List<Time_Sheet_Entry__c> entries = new List<Time_Sheet_Entry__c>();

        for (Integer x = 0; x < 5; x++){
            entries.add(new Time_Sheet_Entry__c(
                    Day_of_the_Week__c  = sheet1.Week__c.addDays(x),
                    Time_Sheet__c       = sheet1.Id,
                    Billable__c         = codes[x].Non_Billable__c,
                    CI_Code__c          = codes[x].Id,
                    Quantity_Number__c  = x + 1
            ));
        }

        insert entries;
    }

    // test get records from the prior week's report
    @IsTest
    public static void testGetRecordsPriorWeek(){

        // get time sheet from week prior
        Time_Sheet__c sheet     = [SELECT Id, Week__c FROM Time_Sheet__c
                                    WHERE Week__c = :Date.today().toStartOfWeek().addDays(-7)];

        // get controller response
        Object controllerResponse       = TimeSheetController.getRecords(sheet.Id);
        Map<String,Object> responseMap  = (Map<String,Object>)controllerResponse;

        // verify controller return values
        List<Date> dates = (List<Date>)responseMap.get('dates');
        System.assertEquals(5, dates.size());

        Map<String,List<List<Object>>> existingRecords = (Map<String,List<List<Object>>>)responseMap.get('existingRecords');
        System.assertEquals(5, existingRecords.size());

        Map<String,List<List<Object>>> priorRecords = (Map<String,List<List<Object>>>)responseMap.get('priorRecords');
        System.assertEquals(0, priorRecords.size());

        List<CI_Code__c> codes = (List<CI_Code__c>)responseMap.get('codes');
        System.assertEquals(1, codes.size());
    }

    // test get records from the prior week's report
    @IsTest
    public static void testGetRecordsCurrentWeek(){

        // get time sheet from week prior
        Time_Sheet__c sheet     = [SELECT Id, Week__c FROM Time_Sheet__c
        WHERE Week__c = :Date.today().toStartOfWeek()];

        List<CI_Code__c> codes = [SELECT Id, Non_Billable__c FROM CI_Code__c];

        // add sample time sheet entries
        List<Time_Sheet_Entry__c> entries = new List<Time_Sheet_Entry__c>();

        for (Integer x = 0; x < 3; x++){
            entries.add(new Time_Sheet_Entry__c(
                    Day_of_the_Week__c  = sheet.Week__c.addDays(x),
                    Time_Sheet__c       = sheet.Id,
                    Billable__c         = codes[x].Non_Billable__c,
                    CI_Code__c          = codes[x].Id,
                    Quantity_Number__c  = x + 1
            ));
        }

        insert entries;

        // get controller response
        Object controllerResponse       = TimeSheetController.getRecords(sheet.Id);
        Map<String,Object> responseMap  = (Map<String,Object>)controllerResponse;

        // verify controller return values
        List<Date> dates = (List<Date>)responseMap.get('dates');
        System.assertEquals(5, dates.size());

        Map<String,List<List<Object>>> existingRecords = (Map<String,List<List<Object>>>)responseMap.get('existingRecords');
        System.assertEquals(3, existingRecords.size());

        Map<String,List<List<Object>>> priorRecords = (Map<String,List<List<Object>>>)responseMap.get('priorRecords');
        System.assertEquals(2, priorRecords.size());

        List<CI_Code__c> responseCodes = (List<CI_Code__c>)responseMap.get('codes');
        System.assertNotEquals(0, responseCodes.size());
    }


    // test update record with integer value
    @IsTest
    public static void testUpdateRecordPositiveValue(){

        // get time sheet id
        Time_Sheet__c sheet = new Time_Sheet__c();
        sheet.Week__c       = Date.today().addDays(7).toStartOfWeek();
        sheet.Department__c = 'Wholesale';
        insert sheet;

        // get single CI code
        String codeId       = [SELECT Id FROM CI_Code__c LIMIT 1].Id;

        // insert existing entry on time sheet
        Time_Sheet_Entry__c entry = new Time_Sheet_Entry__c();
        entry.Time_Sheet__c       = sheet.Id;
        entry.Quantity_Number__c  = 1;
        entry.Day_of_the_Week__c  = sheet.Week__c;
        entry.CI_Code__c          = codeId;
        entry.Billable__c         = false;
        insert entry;

        // call controller update method
        TimeSheetController.updateEntry(sheet.Id, codeId, 0, 2, false);

        // verify database values following controller method execution
        List<Time_Sheet_Entry__c> updatedEntry = [SELECT Id, Day_of_the_Week__c, Quantity_Number__c
                                                    FROM Time_Sheet_Entry__c
                                                    WHERE CI_Code__c = :codeId
                                                    AND Day_of_the_Week__c = :entry.Day_of_the_Week__c];

        // verify that only one record exists for the time sheet with the correct new amount (2) of hours
        System.assertEquals(1, updatedEntry.size());
        System.assertEquals(2, updatedEntry[0].Quantity_Number__c);
    }
}