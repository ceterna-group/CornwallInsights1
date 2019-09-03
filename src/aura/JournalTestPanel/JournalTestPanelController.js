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
    getCompanies : function ($C,$E,$H) {

        $C.set('v.responsePending',true);


        var getUserCompanies = $C.get('c.getUserCompanies');
        getUserCompanies.setCallback(this, function (response) {

            if (response.getState() === 'SUCCESS'){


                $C.set('v.responsePending',false);


                var executions  = $C.get('v.executions');
                $C.set('v.execution', executions.length);
                $C.set('v.iteration',0);

                var execution   = {};
                var companies   = response.getReturnValue();

                companies.forEach(function(company){
                   company.Current      = false;
                   company.Processing   = false;
                });

                execution.Companies = companies;
                executions.push(execution);

                $C.set('v.executions',executions);




                // execution.Companies.forEach(function(company){

                var iterate = $C.get('c.iterate');
                $A.enqueueAction(iterate);

                    // this.doSomething($C);

                    // company.Processing = true;
                    //
                    // var setCompany = $C.get('c.setCurrentCompany');
                    // setCompany.setParams({ companyName : company.c2g__Company__r.Name});
                    // setCompany.setCallback(this, function (response) {
                    //
                    //     company.Processing = false;
                    //     console.log('set company res for ' + company.c2g__Company__r.Name);
                    //     console.log(response);
                    //
                    // });
                    //
                    // $A.enqueueAction(setCompany);

                // });




                // $C.set('v.responsePending',false);

            }

            console.log(response.getReturnValue());

        });
        $A.enqueueAction(getUserCompanies);


        // var dateString  = $C.find('date').get('v.value');
        // var date        = new Date(new Date(dateString).setDate(10));
        //
        // var journalCreate = $C.get('c.generateJournalsApex');
        // journalCreate.setParams({ month : date });
        // journalCreate.setCallback(this, function(response){
        //     $C.set('v.responsePending',false);
        //     console.log(response.getReturnValue());
        //
        //
        //     if (response.getState() === 'SUCCESS'){
        //
        //         var responseObj = response.getReturnValue();
        //         responseObj.name    = 'Test Journals for ' + dateString;
        //
        //         var executions = $C.get('v.executions');
        //         executions.push(response.getReturnValue());
        //         $C.set('v.executions',executions);
        //     }
        // });
        // $A.enqueueAction(journalCreate);
        // $C.set('v.responsePending',true);
    },

    iterate : function ($C) {

        var execution = $C.get('v.execution');
        var executions = $C.get('v.executions');

        var iteration = $C.get('v.iteration');

        console.log('iteration is ' + iteration);
        console.log('count is ' + executions[execution].Companies.length);

        // var companies = $C.get

        if (iteration < executions[execution].Companies.length){

            console.log('should make call');

            var company = executions[execution].Companies[iteration].c2g__Company__r.Name;

            var setCompany = $C.get('c.setCurrentCompany');
            setCompany.setParams({ companyName : company});
            setCompany.setCallback(this, function (response) {

                if (response.getState() === 'SUCCESS'){


                    // company.Processing = false;
                    console.log('set company res for ' + company);
                    console.log('res is ' + response.getReturnValue());


                    console.log('something done ' + iteration);






                    // iteration += 1;
                    // var iteration = $C.set('v.iteration',iteration);




                    //todo:  this needs to happen later
                    var dateString  = $C.find('date').get('v.value');
                    var date        = new Date(new Date(dateString).setDate(10));

                    var createJournals = $C.get('c.generateJournalsApex');
                    createJournals.setParams({
                        month : date,
                        companyName : company
                    });
                    createJournals.setCallback(this, function(createResponse){
                        if (createResponse.getState() === 'SUCCESS'){
                            console.log('res for create is ');
                            console.log(createResponse.getReturnValue());

                            var doSomething = $C.get('c.doSomething');
                            $A.enqueueAction(doSomething);
                        }
                    });

                    $A.enqueueAction(createJournals);




                }




            });

            $A.enqueueAction(setCompany);
            // $C.set('v.iteration',iteration + 1);



        }

        $C.set('v.iteration',iteration + 1);

    }

});



