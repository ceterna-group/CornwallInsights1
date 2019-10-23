/**
 * Created by ronanwilliams on 2019-07-17.
 */

({
    doInit : function($C,$E,$H){

        var recordsCall = $C.get('c.getRecords');
        recordsCall.setParams({
            recordId : $C.get('v.recordId')
        });
        recordsCall.setCallback(this, function(response){
            if (response.getState() === "SUCCESS"){

                var timesheet = $C.get('v.timeSheet');

                console.log(timesheet);

                var responseData = response.getReturnValue();

                var dates   = [];
                var totals  = [];

                for (var x = 0; x< 5; x++){
                    dates.push(new Date(responseData['dates'][x]).toString().substring(0,10));
                    totals.push([0,0]);
                }

                $C.set('v.dates',dates);
                $C.set('v.blockedDates',responseData['blockedDates']);
                $C.set('v.codes',responseData['codes']);
                $C.set('v.billableDefault',responseData['billableDefault']);

                var records         = [];
                var billDefault     = $C.get('v.billableDefault');

                Object.keys(responseData['existingRecords']).forEach(function(record){
                    var recordInfo          = record.split('::');

                    var billableTotal       = 0;
                    var nonBillableTotal    = 0;
                    responseData['existingRecords'][record].forEach(function(day){
                        billableTotal       += day[1] ? day[1] : 0;
                        nonBillableTotal    += day[2] ? day[2] : 0;
                    });

                    records.push({
                        Name : recordInfo[0],
                        Id: recordInfo[1],
                        NotBillable : recordInfo[2] === 'true',
                        Entries : responseData['existingRecords'][record],
                        BillableTotal : billableTotal,
                        NonBillableTotal : nonBillableTotal,
                        ExpandBillable : billDefault || billableTotal > 0,
                        ExpandNonBillable : !billDefault || nonBillableTotal > 0 || recordInfo[2] === 'true'
                    });

                    for (var x = 0; x < responseData['existingRecords'][record].length; x++){
                        var entry = responseData['existingRecords'][record][x];
                        totals[x][0] += entry[1] ? entry[1] : 0;
                        totals[x][1] += entry[2] ? entry[2] : 0;
                    }
                });

                var priorRecords    = [];

                Object.keys(responseData['priorRecords']).forEach(function(record){
                    var priorRecordInfo = record.split('::');

                    priorRecords.push({
                        Name : priorRecordInfo[0],
                        Id: priorRecordInfo[1],
                        NotBillable : priorRecordInfo[2] === 'true',
                        Entries : responseData['priorRecords'][record],
                        BillableTotal : 0,
                        NonBillableTotal : 0,
                        ExpandBillable : billDefault,
                        ExpandNonBillable : !billDefault || priorRecordInfo[2] === 'true'
                    });
                });

                $C.set('v.records',records);
                $C.set('v.priorRecords',priorRecords);
                $C.set('v.totals',totals);
            }
        });
        $A.enqueueAction(recordsCall);

    },
    prefillEntries : function($C,$E,$H){

        var records         = $C.get('v.records');
        var priorRecords    = $C.get('v.priorRecords');
        var codeList        = $C.get('v.codes');
        var usedCodes       = new Set();

        priorRecords.forEach(function(priorRecord){
            records.push(priorRecord);
            usedCodes.add(priorRecord.Name);
        });

        for (var x = 0; x< codeList.length; x++){
            if (usedCodes.has(codeList[x].Name)){
                codeList.splice(x,1);
            }
        }

        $C.set('v.records',records);
        $C.set('v.priorRecords',[]);
        $C.set('v.codes',codeList);
    },
    setRow : function($C,$E,$H){

        var code = $C.find('codelistInput').getElement().value;

        if (code){
            var valid           = false;
            var codeList        = $C.get('v.codes');
            var codeId          = '';
            var notBillable     = false;
            var billDefault     = $C.get('v.billableDefault');

            for (var x = 0; x< codeList.length; x++){
                if (codeList[x].Name === code){
                    valid       = true;
                    codeId      = codeList[x].Id;
                    notBillable = codeList[x].Non_Billable__c;
                    codeList.splice(x,1);
                }
            }

            if (valid){
                var priorRecords    = $C.get('v.priorRecords');
                for (var x = 0; x < priorRecords.length; x++){
                    if (priorRecords[x].Name === code){
                        priorRecords.splice(x,1);
                    }
                }

                $C.set('v.priorRecords',priorRecords);
                $C.find('codelistInput').getElement().value = '';

                var blockedDates    = $C.get('v.blockedDates');
                var records         = $C.get('v.records');

                records.push({
                    Name : code,
                    Id : codeId,
                    NotBillable : notBillable,
                    Entries : [[blockedDates[0],'',''],[blockedDates[1],'',''],[blockedDates[2],'',''],
                        [blockedDates[3],'',''],[blockedDates[4],'','']],
                    BillableTotal : 0,
                    NonBillableTotal : 0,
                    ExpandBillable : billDefault && !notBillable,
                    ExpandNonBillable : !billDefault || notBillable
                });

                $C.set('v.records',records);
                $C.set('v.codes',codeList);
            }
        }
    },
    setActiveField : function($C,$E,$H){

        var allValid = $C.find('timeSheetEntry').reduce(function (validSoFar, inputCmp) {
            return validSoFar && inputCmp.get('v.validity').valid;
        }, true);

        if (allValid){
            var fieldInfo = $E.getSource().get('v.name').split('::');
            $C.set('v.activeField',{
                CodeId : fieldInfo[2],
                AuraId : $E.getSource().get('v.name'),
                Billable : fieldInfo[0] === 'billable',
                Day : fieldInfo[1],
                OriginalAmount : fieldInfo[3],
                RecordIndex : fieldInfo[4]
            });
        }
    },
    adjustEntry : function($C,$E,$H){

        var records     = $C.get('v.records');
        var totals      = $C.get('v.totals');
        var activeField = $C.get('v.activeField');
        var billable    = activeField.Billable ? 1 : 2;
        var newAmount   = records[activeField.RecordIndex].Entries[activeField.Day][billable] ?
            records[activeField.RecordIndex].Entries[activeField.Day][billable] : 0;
        var remainingHours = 24 - (totals[activeField.Day][0] + totals[activeField.Day][1] - activeField.OriginalAmount);

        if (newAmount && newAmount > remainingHours){
            newAmount = remainingHours;
            records[activeField.RecordIndex].Entries[activeField.Day][billable] = newAmount;
        }

        var newTotal    = activeField.Billable ? 'BillableTotal' : 'NonBillableTotal';

        var allValid = $C.find('timeSheetEntry').reduce(function (validSoFar, inputCmp) {
            inputCmp.showHelpMessageIfInvalid();
            return validSoFar && inputCmp.get('v.validity').valid;
        }, true);

        if (allValid && activeField.OriginalAmount !== newAmount){

            $C.set('v.responsePending',true);

            var recordUpdate = $C.get('c.updateEntry');
            recordUpdate.setParams({
                sheetId : $C.get('v.recordId'),
                codeId : activeField.CodeId,
                day : activeField.Day,
                amount : newAmount,
                billable : activeField.Billable
            });

            recordUpdate.setCallback(this, function(response){
                $C.set('v.responsePending',false);
                if (response.getState() === 'SUCCESS' && response.getReturnValue()){
                    records[activeField.RecordIndex][newTotal] += (newAmount - activeField.OriginalAmount);
                    totals[activeField.Day][billable - 1] += (newAmount - activeField.OriginalAmount);
                    $C.set('v.records',records);
                    $C.set('v.totals',totals);
                    $A.get('e.force:refreshView').fire();
                    console.log('REFRESH VIEW FIRED');
                } else {
                    console.log('error with state: ' + response.getState());
                }
            });
            $A.enqueueAction(recordUpdate);
        }
    },
    expandRow : function ($C,$E,$H) {

        var recordName  = $E.currentTarget.dataset.name;
        var records     = $C.get('v.records');
        var billDefault = $C.get('v.billableDefault');

        records.forEach(function(record){
            if (record.Name === recordName){
                if (billDefault){
                    record.ExpandNonBillable = !record.ExpandNonBillable;
                } else {
                    record.ExpandBillable = !record.ExpandBillable;
                }
            }
        });

        $C.set('v.records',records);
    },
    deleteRow : function($C,$E,$H){

        var sourceData  = $E.currentTarget.dataset;
        var records     = $C.get('v.records');
        var codes       = $C.get('v.codes');

        for (var x = 0; x < records.length; x++){
            if (records[x].Id === sourceData.id){
                codes.push({
                    Name : records[x].Name,
                    Id : sourceData.id,
                    Non_Billable__c : records[x].NotBillable
                });
                records.splice(x,1);
            }
        }

        $C.set('v.records',records);
        $C.set('v.codes',codes);
    }
});