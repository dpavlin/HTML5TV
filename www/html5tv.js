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

        var html = '<img src="' + event.args.src + '" width="' + html5tv.slide.width + '" height="' + html5tv.slide.height + '" alt="' + event.args.description + '" id="' + event.args.id + '" /><div class="thumbnailOverlay">' + event.args.title + '</div>';

        carousel.add(i, html);

        myCarousel_addClickHandler(event.args.id, event.startTime);
    }
}

function seek_video(time) {
	var videoElement = $("video#vid").get(0);
	videoElement.currentTime = time;
}


function myCarousel_addClickHandler(id, time) {
    $("#" + id).click(function() {
		seek_video( time );
    });
}

function chapterChange(isActive, args) {

//console.debug( isActive, args );

    if (isActive) {
        $("#carousel img").css("border-color", "#272928");
        $("#" + args.id).css("border-color", "white");
        $("#carousel .thumbnailOverlay").css("visibility", "hidden");
        $("#" + args.id + " + .thumbnailOverlay").css("visibility", "visible");

		$('#sub_' + args.index).addClass('active');

        theCarousel.scroll(args.index, true);
    } else {
		$('#sub_' + args.index).removeClass('active');
	}
}


function additional_video(isActive, args) {
	var video = $('video#' + args.id);
//console.debug( isActive, args, video );
	if (isActive) {
		$('div#slide').hide();
		video.show();
		video[0].play();
	} else {
		video[0].pause();
		video.hide();
		$('div#slide').show();
	}
}


$().ready(function() {
//console.debug( video_sync );
   	$("#vid").sync( html5tv.sync );

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

	$('td.seek_video').click( function() {
//console.debug( 'click', this );
			var to = this.textContent;
//console.debug( 'seek', to );
			seek_video( to );
	} );
});
