/**
 * Created by ronanwilliams on 2019-07-17.
 */

({

    afterRender : function($C,$H) {
        var listInputCmp    = $C.find("codelistInput");
        var listInput       = listInputCmp.getElement();
        // listInput.setAttribute("list", "codelist");
        listInput.setAttribute("list", $C.get('v.recordId'));
        //
        // console.log('superAfterRender fired');
        //
        // return this.superAfterRender();
    }

})