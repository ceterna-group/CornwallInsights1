/**
 * Created by ronanwilliams on 2019-07-17.
 */

public class TimeSheetController {

    @AuraEnabled
    public static Object getRecords(Id recordId){

        // declare response map object to be returned to jsController
        Map<String,Object> responseMap = new Map<String,Object>();

        Time_Sheet__c sheet = [SELECT Id, Week__c, CreatedById, Prefilled__c, Billable_vs_Non_Billable_Layout_Render__c
                                FROM Time_Sheet__c WHERE Id = :recordId];

        // generate dates for each day of the week, commencing with the start date (Monday) on the time sheet
        List<Date> dates            = new List<Date>();
        List<Boolean> blockedDates  = new List<Boolean>();

        for (Integer x = 0; x < 5; x++){
            Date entryDate = sheet.Week__c.toStartOfWeek().addDays(x);
            dates.add(entryDate);
            blockedDates.add(entryDate > Date.today() || entryDate.toStartOfWeek() < Date.today().toStartOfWeek().addDays(-14));
        }

        responseMap.put('dates',dates);
        responseMap.put('blockedDates',blockedDates);
        responseMap.put('billableDefault',sheet.Billable_vs_Non_Billable_Layout_Render__c);

        // isolate ids of codes already used in existing time sheet entries
        Set<Id> usedCodes = new Set<Id>();

        // declare map of existing time sheet entries for the current week
        Map<String,List<List<Object>>> entryMap = new Map<String,List<List<Object>>>();

        // add code groupings based on existing time sheet entries
        for (Time_Sheet_Entry__c entry : [SELECT Id, Name, CI_Code__c, CI_Code__r.Name, CI_Code__r.Non_Billable__c,
                                                    Billable__c, Quantity_Number__c, Day_of_the_Week__c
                                          FROM Time_Sheet_Entry__c
                                          WHERE Time_Sheet__c = :recordId
                                          AND CI_Code__r.Name != NULL]){

            usedCodes.add(entry.CI_Code__c);
            Integer index   = entry.Billable__c ? 1 : 2;
            String codeKey  = entry.CI_Code__r.Name +'::'+ entry.CI_Code__c +'::'+ entry.CI_Code__r.Non_Billable__c;

            // if the entry map does not yet contain the code, add it to the map
            if (!entryMap.containsKey(codeKey)){
                List<List<Object>> days = new List<List<Object>>();
                for (Integer x = 0; x < 5; x++){
                    days.add(new List<Object>{blockedDates[x],'',''});
                }
                entryMap.put(codeKey,days);
            }

            // add the relevant amount to the map
            if (entry.Quantity_Number__c != null){
                if (entryMap.get(codeKey)[sheet.Week__c.daysBetween(entry.Day_of_the_Week__c)][index] == ''){
                    entryMap.get(codeKey)[sheet.Week__c.daysBetween(entry.Day_of_the_Week__c)][index] = entry.Quantity_Number__c;
                } else {
                    Decimal value = (Decimal)entryMap.get(codeKey)[sheet.Week__c.daysBetween(entry.Day_of_the_Week__c)][index];
                    entryMap.get(codeKey)[sheet.Week__c.daysBetween(entry.Day_of_the_Week__c)][index] = value + entry.Quantity_Number__c;
                }
            }
        }

        responseMap.put('existingRecords',entryMap);

        // declare map of time sheet entries for the prior week, without preserving values
        Map<String,List<List<Object>>> priorEntryMap = new Map<String,List<List<Object>>>();

        // add code groupings based on existing time sheet entries
        for (Time_Sheet_Entry__c entry : [SELECT Id, Name, CI_Code__c, CI_Code__r.Name, Billable__c,
                                                CI_Code__r.Non_Billable__c, Quantity_Number__c, Day_of_the_Week__c
                                            FROM Time_Sheet_Entry__c
                                            WHERE CreatedById = :sheet.CreatedById
                                            AND Time_Sheet__r.Week__c = :sheet.Week__c.addDays(-7)
                                            AND CI_Code__c NOT IN :usedCodes
                                            AND CI_Code__r.Name != :NULL]){

            String codeKey  = entry.CI_Code__r.Name +'::'+ entry.CI_Code__c +'::'+ entry.CI_Code__r.Non_Billable__c;

            // if the entry map does not yet contain the code, add it to the map
            if (!priorEntryMap.containsKey(codeKey)){
                List<List<Object>> days = new List<List<Object>>();
                for (Integer x = 0; x < 5; x++){
                    days.add(new List<Object>{blockedDates[x],'',''});
                }
                priorEntryMap.put(codeKey,days);
            }
        }

        responseMap.put('priorRecords',priorEntryMap);

        // find all ci codes not already referenced in existing time sheet entries and add them to the response map
        List<CI_Code__c> codes = [SELECT Id, Name, Non_Billable__c FROM CI_Code__c WHERE Id NOT IN :usedCodes];
        responseMap.put('codes',codes);

        return responseMap;
    }

    @AuraEnabled
    public static Object updateEntry(String sheetId, String codeId, Integer day, Decimal amount, Boolean billable){

        // retrieve the original timesheet
        Time_Sheet__c sheet = [SELECT Id, Week__c FROM Time_Sheet__c WHERE Id = :sheetId];

        // determine the date of the timesheet entry to be edited
        Date entryDate = sheet.Week__c.addDays(day);

        // declare a new time sheet entry to be upserted
        Time_Sheet_Entry__c entry   = new Time_Sheet_Entry__c(
                Day_of_the_Week__c  = entryDate,
                Billable__c         = billable,
                Quantity_Number__c  = amount,
                CI_Code__c          = codeId,
                Time_Sheet__c       = sheetId
        );

        List<Time_Sheet_Entry__c> entries = [SELECT Id FROM Time_Sheet_Entry__c
                                             WHERE Time_Sheet__c = :sheetId
                                             AND Day_of_the_Week__c = :entryDate
                                             AND CI_Code__c = :codeId
                                             AND Billable__c = :billable];

        if (!entries.isEmpty()){
            entry.Id = entries[0].Id;
        }

        Boolean success = true;

        if (entry.Quantity_Number__c != 0){
            Database.UpsertResult upsertResult = Database.upsert(entry);
            success = upsertResult.isSuccess();
        } else if (!entries.isEmpty()){
            Database.DeleteResult deleteResult = Database.delete(entries[0]);
            success = deleteResult.isSuccess();
        }

        return success;

    }
}