/**
 * Created by ronanwilliams on 2019-08-20.
 */

({

    doInit : function($C,$E,$H){

        var dates = [];
        var today = new Date();

        for (var x = 0; x < 12; x++){
            var month = today.toString().substring(4,7);
            var year = today.getFullYear();
            dates.push(month + ' ' + year);

            var oneMonthAgo = new Date(
                new Date(today).getFullYear(),
                new Date(today).getMonth() - 1,
                new Date(today).getDate()
            );
            today = oneMonthAgo;
        }

        $C.set('v.dates',dates);
    },
    generateJournals : function ($C,$E,$H) {

        var dateString  = $C.find('date').get('v.value');
        var date        = new Date(new Date(dateString).setDate(10));

        var journalCreate = $C.get('c.generateJournalsApex');
        journalCreate.setParams({ month : date });
        journalCreate.setCallback(this, function(response){
            $C.set('v.responsePending',false);
            console.log(response.getReturnValue());


            if (response.getState() === 'SUCCESS'){

                var responseObj = response.getReturnValue();
                responseObj.name    = 'Test Journals for ' + dateString;

                var executions = $C.get('v.executions');
                executions.push(response.getReturnValue());
                $C.set('v.executions',executions);
            }
        });
        $A.enqueueAction(journalCreate);
        $C.set('v.responsePending',true);
    }

});



