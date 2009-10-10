var theCarousel;

function myCarousel_initCallback(carousel) {
    theCarousel = carousel; // hack!
}

function myCarousel_onBeforeAnimation(carousel, state) {
    for (var i = carousel.first; i <= carousel.last; i++) {
        if (carousel.has(i)) {
            continue;
        }

        if (i > carousel.options.customEventManager.getEventCount()) {
            break;
        }

        var event = carousel.options.customEventManager.getEvent(i - 1);

        var html = '<img src="' + event.args.src + '" width="117" height="66" alt="' + event.args.description + '" id="' + event.args.id + '" /><div class="thumbnailOverlay">' + event.args.title + '</div>';

        carousel.add(i, html);

        myCarousel_addClickHandler(event.args.id, event.startTime);
    }
}

function myCarousel_addClickHandler(id, time) {
    $("#" + id).click(function() {
        var videoElement = $("video#vid").get(0);
        videoElement.currentTime = time;
    });
}

function chapterChange(isActive, args) {
    if (isActive) {
        $("#carousel img").css("border-color", "#272928");
        $("#" + args.id).css("border-color", "white");
        $("#carousel .thumbnailOverlay").css("visibility", "hidden");
        $("#" + args.id + " + .thumbnailOverlay").css("visibility", "visible");

        theCarousel.scroll(args.index, true);
    }
}

$().ready(function() {
	//console.debug( video_sync );
   	$("#vid").sync( video_sync );

    $(".toggleContentPanel").click(function() {
        var contentPanelId = "#" + ($(this).attr("class")).split(" ")[1];
        $(contentPanelId).toggle("blind", {}, 100);
        var currentBackground = $(this).css("background-image");
        var newBackground = currentBackground.indexOf("Show") >=0 ? "url(contentPanelHide.png)" : "url(contentPanelShow.png)";
        $(this).css("background-image", newBackground);
    });

    var synchroniser = $("#vid").data("synchroniser");

    var customEventManager = synchroniser.getCustomEventManager();
    var chapterCount = customEventManager.getEventCount();

    $('#carousel').jcarousel({
        size: chapterCount,
        itemLoadCallback: {
            onBeforeAnimation: myCarousel_onBeforeAnimation
        },
        initCallback: myCarousel_initCallback,
        customEventManager: customEventManager
    });
});
