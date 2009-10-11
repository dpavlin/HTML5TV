(function($) {

    /**
     * Event constructor.
     */

    var Event = function(startTime, endTime) {
        this.isActive = false;
        this.startTime = startTime;
        this.endTime = endTime;
        return this;
    };

    /**
     * Returns true if the Event should be active, i.e., the media
     * playback time lies within the start and end times of the Event.
     */

    Event.prototype.shouldBeActive = function(time) {
        return time >= this.startTime && time < this.endTime;
    };

    /**
     * Activates or deactivates the Event, according to the isActive flag.
     */

    Event.prototype.setActive = function(isActive) {
        this.isActive = isActive;
    }

    /**
     * HtmlEvent constructor.
     */

    var HtmlEvent = function(startTime, endTime, selector, html) {
        Event.call(this, startTime, endTime);
        this.selector = selector;
        this.html = html;
        return this;
    };

    HtmlEvent.prototype = new Event();

    /**
     * Activates or deactivates the HtmlEvent.
     */

    HtmlEvent.prototype.setActive = function(isActive) {
        Event.prototype.setActive.call(this, isActive);

        if (isActive) {
            $(this.selector).html(this.html);
        }
        else {
            $(this.selector).html("");
        }
    }

    /**
     * StyleEvent constructor.
     */

    var StyleEvent = function(startTime, endTime, selector, cssClass) {
        Event.call(this, startTime, endTime);
        this.selector = selector;
        this.cssClass = cssClass;
        return this;
    };

    StyleEvent.prototype = new Event();

    StyleEvent.prototype.setActive = function(isActive) {
        Event.prototype.setActive.call(this, isActive);

        if (isActive) {
            $(this.selector).addClass(cssClass);
        }
        else {
            $(this.selector).removeClass(cssClass);
        }
    }

    /**
     * CustomEvent constructor.
     */

    var CustomEvent = function(startTime, endTime, action, args) {
        Event.call(this, startTime, endTime);
        this.action = action;
        this.args = args;
        return this;
    };

    CustomEvent.prototype = new Event();

    /**
     * Activates or deactivates the CustomEvent.
     */

    CustomEvent.prototype.setActive = function(isActive) {
        Event.prototype.setActive.call(this, isActive);

        eval( this.action + '(isActive, this.args)' ); // FIXME ugly
    }

    /**
     * EventManager constructor.
     */

    var EventManager = function() {
        this.events = [];
        this.currentActiveEvent = null;
        return this;
    };

    /**
     * Adds an Event to the EventManager.
     */

    EventManager.prototype.addEvent = function(event) {
        this.events.push(event);
    };

    /**
     * Sorts the Events held by the EventManager by ascending start time.
     */

    EventManager.prototype.sort = function() {
        this.events.sort(function(a, b) {
            return a.startTime - b.startTime;
        });
    };

    /**
     * Updates the EventManager, given the current media playback time, which
     * may cause events to be activated or deactivated.
     */

    EventManager.prototype.update = function(time) {
        var event = this.findActiveEvent(time);

        if (event != this.currentActiveEvent) {
            if (this.currentActiveEvent) {
                this.currentActiveEvent.setActive(false);
            }

            this.currentActiveEvent = event;

            if (event) {
                event.setActive(true);
            }
        }
    };

    /**
     * Returns the event that should be active, given the current media
     * playback time, or null if no event should be active.
     *
     * Note that this assumes there can only be one active event within
     * each EventManager object at a time.
     */

    EventManager.prototype.findActiveEvent = function(time) {
        var event = null;
        var i, length;

        /* Check whether the current event should still be active. If not,
           search for a new event. */
        if (this.currentActiveEvent && this.currentActiveEvent.shouldBeActive(time)) {
            event = this.currentActiveEvent;
        }
        else {
            length = this.events.length;

            for (i = 0; i < length; i++) {
                if (this.events[i].shouldBeActive(time)) {
                    event = this.events[i];
                    break;
                }
            }
        }

        return event;
    };

    EventManager.prototype.getEventCount = function() {
        return this.events.length;
    };

    EventManager.prototype.getEvent = function(index) {
        var event = null;

        if (index >= 0 && index < this.events.length) {
            event = this.events[index];
        }

        return event;
    };

    /**
     * TimeCounter constructor.
     */

    var TimeCounter = function(selector, timeFormatter) {
        this.counterObject = $(selector);
        this.currentFormattedTime = "";

        if (timeFormatter) {
            this.formatTime = timeFormatter;
        }
    };

    TimeCounter.prototype.update = function(time) {
        var formattedTime = this.formatTime(time);

        if (formattedTime != this.currentFormattedTime) {
            this.currentFormattedTime = formattedTime;
            this.counterObject.html(formattedTime);
        }
    };

    TimeCounter.prototype.formatTime = function(time) {
        return time.toFixed(2);
    }

    /**
     * Synchroniser constructor.
     */

    var Synchroniser = function(options) {
        this.customEventManager = null;
        /* Array of objects that are objects that are synchronisable, i.e., have
           an update(time) method. */
        this.synchronisables = [];

        if (options.hasOwnProperty("htmlEvents")) {
            this.initEvents(options.htmlEvents, function(event, selector) {
                return new HtmlEvent(event.startTime, event.endTime, selector, event.html);
            });
        }

        if (options.hasOwnProperty("styleEvents")) {
            this.initEvents(options.styleEvents, function(event, selector) {
                return new StyleEvent(event.startTime, event.endTime, selector, options.activeStyle);
            });
        }

        if (options.hasOwnProperty("timeCounter")) {
            var selector = options.timeCounter.selector;
            var timeFormatter = options.timeCounter.timeFormatter;

            if (selector) {
                this.initCounter(selector, timeFormatter);
            }
        }

        if (options.hasOwnProperty("customEvents")) {
            this.customEventManager =  this.initEventManager(options.customEvents, function(event, selector) {
                return new CustomEvent(event.startTime, event.endTime, event.action, event.args);
            });

            this.synchronisables.push(this.customEventManager);
        }
    };

    Synchroniser.prototype.initEvents = function(events, factory) {
        var selector;
        var eventManager; /* eventManager contains a set of events for a single selector. */

        for (selector in events) {
            if (events.hasOwnProperty(selector)) {
                eventManager = this.initEventManager(events[selector], factory, selector);

                this.synchronisables.push(eventManager);
            }
        }
    }

    Synchroniser.prototype.initEventManager = function(events, factory, selector) {
        var eventManager = new EventManager();
        var i, length = events.length;
        var event;

        for (i = 0; i < length; i++) {
            /* Call the factory function to create the event object. */
            event = factory.call(this, events[i], selector);
            eventManager.addEvent(event);
        }

        eventManager.sort();

        return eventManager;
    };

    Synchroniser.prototype.initCounter = function(selector, timeFormatter) {
        var timeCounter = new TimeCounter(selector, timeFormatter);
        this.synchronisables.push(timeCounter);
    }

    Synchroniser.prototype.update = function(time) {
        var i, length = this.synchronisables.length;

        for (i = 0; i < length; i++) {
            this.synchronisables[i].update(time);
        }
    };

    Synchroniser.prototype.getCustomEventManager = function() {
        return this.customEventManager;
    };

    $.fn.sync = function(options) {
        options = $.extend({}, $.fn.sync.defaults, options);

        var synchroniser = new Synchroniser(options);

        return this.each(function() {
            $(this).data("synchroniser", synchroniser);

            $(this).bind("timeupdate", function(event) {
                synchroniser.update(event.target.currentTime);
            });
        });
    };

    /* Default configuration properties. */
    $.fn.sync.defaults = {
        timeCounter: {
            selector: '',
            timeFormatter: null
        },

        /* CSS class to be added to selectors when a StyleEvent is active. */
        activeClass: 'syncActive'
    };

})(jQuery);
