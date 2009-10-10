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
    $("#vid").sync({
        htmlEvents: {
            "#subtitle": [
                { startTime: 31.78,   endTime: 35.291,  html: "It is half past 9 and we've just passed Sheffield" },
                { startTime: 35.292,  endTime: 37.43,   html: "and we're coming home from Maker Faire in Newcastle" },
                { startTime: 54.594,  endTime: 58.932,  html: "I'm here with BBC R&D at Maker Faire UK Newcastle 2009" },
                { startTime: 58.933,  endTime: 61.221,  html: "and we have some demos we're also making some stuff" },
                { startTime: 61.222,  endTime: 63.049,  html: "but we have some demos too." },
                { startTime: 63.05,   endTime: 65.354,  html: "What we have here is a webcam in a cardboard box" },
                { startTime: 65.355,  endTime: 67.583,  html: "with a picture frame on top of it and we're using this" },
                { startTime: 67.584,  endTime: 70.294,  html: "to prototype the next generation of computer interaction." },
                { startTime: 70.295,  endTime: 73.455,  html: "It's getting these very, very, very wobbly little cams" },
                { startTime: 73.456,  endTime: 75.94,   html: "Something like this, you could, well, we have actually" },
                { startTime: 75.941,  endTime: 78.562,  html: "strapped it to someone's head, like, uh, so they can" },
                { startTime: 78.563,  endTime: 79.823,  html: "go like this and then" },
                { startTime: 79.824,  endTime: 82.603,  html: "the cunning thing we do then is we press this button here" },
                { startTime: 84.231,  endTime: 86.389,  html: "is it F? Oh god no that isn't the one" },
                { startTime: 86.39,   endTime: 87.39,   html: "<LAUGHS" },
                { startTime: 87.391,  endTime: 91.167,  html: "Right, er, yeah OK" },
                { startTime: 91.168,  endTime: 93.258,  html: "there we go, it's steadied" },
                { startTime: 94.129,  endTime: 96.523,  html: "Multitouch is considered by a lot of people" },
                { startTime: 96.524,  endTime: 97.551,  html: "thinking about it to be" },
                { startTime: 97.652,  endTime: 99.484,  html: "the next generation of computer interaction" },
                { startTime: 99.485,  endTime: 102.765, html: "there are a lot of possibilities for extending" },
                { startTime: 102.766, endTime: 105.555, html: "the existing mouse and keyboard metaphor" },
                { startTime: 105.59,  endTime: 108.344, html: "into interacting with touch surfaces." },
                { startTime: 111.972, endTime: 114.267, html: "Dopplr's creating a model of your future travel" },
                { startTime: 114.268, endTime: 115.481, html: "and other people's future travel" },
                { startTime: 115.482, endTime: 117.524, html: "and then we let you play with it." },
                { startTime: 117.525, endTime: 122.088, html: "So what if you were travelling to Sydney, we could tell you" },
                { startTime: 122.089, endTime: 124.684, html: "oh, by the way Matt Biddulph will be there" },
                { startTime: 124.685, endTime: 127.357, html: "2 days before you arrive. You might choose to change your flight" },
                { startTime: 127.358, endTime: 128.944, html: "so that we could hang out there." },
                { startTime: 128.945, endTime: 133.583, html: "And by looking at this model which lets you think" },
                { startTime: 133.584, endTime: 135.457, html: "about what's going to happen in the real world," },
                { startTime: 135.458, endTime: 137.657, html: "we give you this superpower" },
                { startTime: 137.658, endTime: 140.069, html: "of being able to play what-if, with your future" },
                { startTime: 140.07,  endTime: 143.056, html: "we hope that people will never eat a bad hamburger" },
                { startTime: 143.057, endTime: 146.937, html: "in a hotel restaurant by themselves in a on-site trip again" },
                { startTime: 146.938, endTime: 148.891, html: "if they're using our service." },
                { startTime: 152.216, endTime: 154.715, html: "One of the projects that we're working on" },
                { startTime: 154.716, endTime: 156.761, html: "is called the Ingex project" },
                { startTime: 156.762, endTime: 161.646, html: "and that is all about low cost tapeless TV production" },
                { startTime: 161.647, endTime: 166.409, html: "Ingex uses low-cost commodity PC hardware" },
                { startTime: 166.41,  endTime: 168.324, html: "and video capture cards" },
                { startTime: 168.325, endTime: 172.162, html: "and on that we run open-source software" },
                { startTime: 172.163, endTime: 175.201, html: "which gives us a very low-cost solution." },
                { startTime: 175.202, endTime: 180,     html: "But despite that it still gives us many of the features" },
                { startTime: 180.001, endTime: 184.256, html: "that we require for professional production in a TV studio." },
                { startTime: 184.257, endTime: 188.604, html: "One of the challenges that we faced developing Ingex" },
                { startTime: 188.605, endTime: 192.517, html: "is really to keep the system as simple as possible" },
                { startTime: 192.518, endTime: 194.154, html: "for the users in the studio." },
                { startTime: 194.155, endTime: 198.253, html: "But also to make sure that it's as reliable as they need." },
                { startTime: 198.254, endTime: 200.889, html: "Because we can't have PCs failing" },
                { startTime: 200.89,  endTime: 204.79,  html: "bringing the studio to a halt whilst they're fixed." },
                { startTime: 204.791, endTime: 209.073, html: "So we spend a lot of time keeping everything very simple," },
                { startTime: 209.074, endTime: 213.584, html: "so the user can be familiar with it without a lot of training" },
                { startTime: 213.585, endTime: 218.248, html: "but also making sure that any problems in the background" },
                { startTime: 218.249, endTime: 222.447, html: "really are left to the software to sort out automatically." },
                { startTime: 226.602, endTime: 228.869, html: "Mahalo is a human powered search engine." },
                { startTime: 228.87,  endTime: 233.295, html: "And it's essentially Google plus Wikipedia" },
                { startTime: 233.296, endTime: 236.551, html: "if you were to type a search, for say Green Tea." },
                { startTime: 236.552, endTime: 239.427, html: "We would have a human spend two, three hours" },
                { startTime: 239.428, endTime: 240.864, html: "researching Green Tea on the internet," },
                { startTime: 240.865, endTime: 243.989, html: "reading all the best sites, finding all the great links" },
                { startTime: 243.99,  endTime: 246.807, html: "and then making a guided page for you that would be" },
                { startTime: 246.808, endTime: 250.184, html: "fast facts about green tea and items about green tea" },
                { startTime: 250.285, endTime: 251.951, html: "actual content that we'll write" },
                { startTime: 251.952, endTime: 255.705, html: "then we have sections on the top 7 links for green tea," },
                { startTime: 255.706, endTime: 259.778, html: "green tea how-to articles, green tea photos," },
                { startTime: 259.779, endTime: 262.041, html: "green tea videos, green tea merchants," },
                { startTime: 262.042, endTime: 265.525, html: "green tea related teas etc." },
                { startTime: 265.526, endTime: 268.986, html: "So essentially adding 2 or 3 hours of curation" },
                { startTime: 268.987, endTime: 272.647, html: "of human intelligence, to a machine search" },
                { startTime: 272.648, endTime: 274.365, html: "so it's not just humans" },
                { startTime: 274.366, endTime: 277.045, html: "it's humans using machines to make a better result." }
            ]
        },
        customEvents: [
            {
                startTime: 0.0,
                endTime: 26.9,
                action: chapterChange,
                args: {
                    carousel: theCarousel,
                    id: "chapter1",
                    index: 1,
                    title: "Introduction",
                    description: "Introduction and title music",
                    src: "introduction.jpg",
                    href: ""
                }
            },
            {
                startTime: 27.0,
                endTime: 107.9,
                action: chapterChange,
                args: {
                    carousel: theCarousel,
                    id: "chapter2",
                    index: 2,
                    title: "BBC R&D at the Maker Faire",
                    description: "Engaging with our audiences. BBC R&D at the Maker Faire.",
                    src: "makerfaire.jpg",
                    href: ""
                }
            },
            {
                startTime: 108.0,
                endTime: 147.9,
                action: chapterChange,
                args: {
                    carousel: theCarousel,
                    id: "chapter3",
                    index: 3,
                    title: "Maximising the serendipity of travel",
                    description: "Maximising the serendipity of travel. Matt Biddulph, CTO of Dopplr.",
                    src: "biddulph.jpg",
                    href: ""
                }
            },
            {
                startTime: 148.0,
                endTime : 221.9,
                action: chapterChange,
                args: {
                    carousel: theCarousel,
                    id: "chapter4",
                    index: 4,
                    title: "Ingex",
                    description: "Ingex. Automated tapeless production tool.",
                    src: "ingex.jpg",
                    href: ""
                }
            },
            {
                startTime: 222.0,
                endTime: 276.9,
                action: chapterChange,
                args: {
                    carousel: theCarousel,
                    id: "chapter5",
                    index: 5,
                    title: "Human powered search",
                    description: "Human powered search. Jason Calacanis, CEO of Mahalo.com.",
                    src: "calacanis.jpg",
                    href: ""
                }
            },
            {
                startTime: 277.0,
                endTime: 320,
                action: chapterChange,
                args: {
                    carousel: theCarousel,
                    id: "chapter6",
                    index: 6,
                    title: "Credits",
                    description: "End credits",
                    src: "credits.jpg",
                    href: ""
                }
            }
        ]
    });

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
