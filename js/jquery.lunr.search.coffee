(($) ->
  debounce = (fn) ->
    timeout = undefined
    slice = Array::slice
    ->
      args = slice.call(arguments)
      ctx = this
      clearTimeout timeout
      timeout = setTimeout(->
        fn.apply ctx, args
        return
      , 100)
      return

  LunrSearch = (elem, options) ->
    # store all the elements
    @search_elem = elem
    @quickSearchResults = $(options.quickSearchResults)
    @quickSearchEntries = $(options.quickSearchEntries, @quickSearchResults)
    @searchResults = $(options.searchResults)
    @searchEntries = $(options.searchEntries, @searchResults)

    @indexDataUrl = options.indexUrl

    @quickSearchTemplate = @compileTemplate($(options.quickSearchTemplate))
    @searchTemplate = @compileTemplate($(options.searchTemplate))

    @searchMoreButton = $(".search-more-button")
    @searchSpinner = $(".search-spinner")
    @searchHeader = $(".search-header")

    @searchWorker = new Worker("/assets/javascripts/search_worker.js")

    # fetch the data, then ask the worker to index it
    @loadIndexData (data) =>
      data.type = index: true
      @searchWorker.postMessage data

    # bind the input bar events
    @bindQuicksearchKeypress()
    @bindQuicksearchBlur()
    @bindQuicksearchFocus()

    @searchWorker.addEventListener "message", (e) =>
      if e.data.type.indexed
        # if this is on /search, try a search
        @populateSearchFromQuery()
      else
        if e.data.type.quicksearch
          @displayQuicksearch e.data.query, e.data.results
        else
          @displaySearchResults e.data.query, e.data.results

    @searchMoreButton.on "click", (e) =>
      if @page? then @page++ else @page = 2
      @populateEntries()
      e.preventDefault()

  # compile search results template
  LunrSearch::compileTemplate = ($template) ->
    template = $template.text()
    x = "{% raw %}"
    Mustache.parse template, "{{ }}"
    x = "{% endraw %}"
    (view, partials) ->
      Mustache.render template, view, partials

  # load the search index data
  LunrSearch::loadIndexData = (callback) ->
    $.getJSON @indexDataUrl, callback

  # on keyup of input, reinitiate search
  LunrSearch::bindQuicksearchKeypress = ->
    oldValue = @search_elem.val()
    @search_elem.bind "keyup", debounce =>
      newValue = @search_elem.val()
      @search newValue, true  if newValue isnt oldValue
      oldValue = newValue

  # on focus of input, show the quicksearch
  LunrSearch::bindQuicksearchFocus = ->
    @search_elem.bind "focus", debounce =>
      @quickSearchResults.show() if @search_elem.val()

  # when clicking away from input, hide the quicksearch
  LunrSearch::bindQuicksearchBlur = ->
    @search_elem.bind "blur", debounce =>
      @quickSearchResults.hide()

  # when clicking a link in quicksearch, follow it, rather than heading to blue
  LunrSearch::bindQuicksearchMousedown = ->
    $(".autocomplete-results a").each (idx, el) ->
      $(el).bind "mousedown", (event) ->
        event.preventDefault()
        return

  # tell the worker you want to search
  LunrSearch::search = (query, quicksearch) ->
    @searchWorker.postMessage
      query: query
      quicksearch: quicksearch
      isSearchPage: @isSearchPage()
      type:
        search: true

  LunrSearch::displayQuicksearch = (query, entries) ->
    @quickSearchEntries.empty()
    if entries.length > 0
      entries = entries.slice(0, 10)
      @quickSearchEntries.append @quickSearchTemplate(entries: entries)
      @quickSearchResults.show()
      $(".quicksearch-seemore").attr "href", "/search?q=" + query
      @bindQuicksearchMousedown()

  LunrSearch::displaySearchResults = (query, entries) ->
    @searchEntries.empty()
    $(".search-query").text query
    if entries.length is 0
      @searchSpinner.addClass "hidden"
      @searchHeader.text "No Results For '#{query}'"
    else
      @entries = entries
      @searchSpinner.addClass "hidden"
      @searchMoreButton.removeClass "hidden"
      @searchHeader.text "Search Results For '#{query}'"
      @populateEntries()

  LunrSearch::populateEntries = ->
    max = 50 * (@page || 1)
    entriesToShow = @entries.slice(max - 50, max - 1)
    if (@entries.length < max)
      @searchMoreButton.addClass "hidden"
    @searchEntries.append @searchTemplate(entries: entriesToShow)

  # Populate the search input with 'q' querystring parameter if set
  LunrSearch::populateSearchFromQuery = ->
    return unless @isSearchPage()

    if m = window.location.search.match /[?&]q=([^&]+)/
      q = decodeURIComponent m[1].replace(/\+/g, " ")
      @search_elem.val q
      @search q, false
    else
      @search " ", false

  # Populate the search input with 'q' querystring parameter if set
  LunrSearch::isSearchPage = -> window.location.pathname.match /\/search\//

  $.fn.lunrSearch = (options) ->
    # apply default options
    options = $.extend({}, $.fn.lunrSearch.defaults, options)

    # create search object
    new LunrSearch(this, options)
    this

) jQuery
