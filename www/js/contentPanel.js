$(document).ready(function(){
	    
	$("#hideIcon, #hideX").click(function () {
		$("#contentPanelContainer").hide("slide", { direction: "right"}, 300);
		setTimeout(function() {$("#showIcon").show();}, 300);
	});
	
	$("#showIcon").click(function () {
	//	$("#videoElementWarning").hide();
		$("#showIcon").hide();
		$("#contentPanelContainer").show("slide", { direction: "right"}, 300);
	});

});

