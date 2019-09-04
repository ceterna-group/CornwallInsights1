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
            today = new Date(new Date(today).getFullYear(), new Date(today).getMonth() - 1, new Date(today).getDate());
        }

        $C.set('v.dates',dates);
    },
    getCompanies : function ($C,$E,$H) {

        $C.set('v.responsePending',true);

        var getUserCompanies = $C.get('c.getUserCompanies');
        getUserCompanies.setCallback(this, function (response) {

            if (response.getState() === 'SUCCESS'){

                var executions  = $C.get('v.executions');
                $C.set('v.execution', executions.length);
                $C.set('v.iteration',0);

                var execution   = {};
                var companies   = response.getReturnValue();

                companies.forEach(function(company){
                   company.Current      = false;
                   company.Processing   = false;
                   company.Journals     = [];
                });

                execution.Companies = companies;
                executions.push(execution);

                $C.set('v.executions',executions);

                var iterate = $C.get('c.iterate');
                $A.enqueueAction(iterate);
            }
        });
        $A.enqueueAction(getUserCompanies);
    },

    iterate : function ($C) {

        var execution   = $C.get('v.execution');
        var executions  = $C.get('v.executions');
        var iteration   = $C.get('v.iteration');

        if (iteration < executions[execution].Companies.length){

            var company = executions[execution].Companies[iteration];

            executions[execution].Companies[iteration].Processing = true;

            $C.set('v.executions',executions);

            var setCompany = $C.get('c.setCurrentCompany');
            setCompany.setParams({ companyName : company.c2g__Company__r.Name});
            setCompany.setCallback(this, function (response) {

                if (response.getState() === 'SUCCESS'){

                    var dateString  = $C.find('date').get('v.value');
                    var date        = new Date(new Date(dateString).setDate(10));

                    var createJournals = $C.get('c.generateJournalsApex');
                    createJournals.setParams({
                        month : date,
                        companyName : company.c2g__Company__r.Name
                    });
                    createJournals.setCallback(this, function(createResponse){
                        if (createResponse.getState() === 'SUCCESS'){

                            executions[execution].Companies[iteration].Journals = createResponse.getReturnValue()['journals'];
                            executions[execution].Companies[iteration].Processing = false;
                            $C.set('v.executions',executions);
                            var iterate = $C.get('c.iterate');
                            $A.enqueueAction(iterate);
                        }
                    });

                    $A.enqueueAction(createJournals);
                }
            });

            $A.enqueueAction(setCompany);
        } else {
            $C.set('v.responsePending',false);
        }

        $C.set('v.iteration',iteration + 1);
    }

});



