$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'

BindingSet = require 'binding-set'
Specificity = require 'specificity'

module.exports =
class Keymap
  bindingSets: null
  queuedKeystrokes: null

  constructor: ->
    @bindingSets = []

  bindDefaultKeys: ->
    @bindKeys "*",
      'meta-n': 'new-window'
      'meta-,': 'open-user-configuration'
      'meta-o': 'open'

    $(document).on 'new-window', => $native.newWindow()
    $(document).on 'open-user-configuration', => atom.open(atom.configFilePath)
    $(document).on 'open', =>
      path = $native.openDialog()
      atom.open(path) if path

  bindKeys: (selector, bindings) ->
    @bindingSets.unshift(new BindingSet(selector, bindings))

  bindingsForElement: (element) ->
    keystrokeMap = {}
    currentNode = $(element)

    while currentNode.length
      bindingSets = @bindingSets.filter (set) -> currentNode.is(set.selector)
      bindingSets.sort (a, b) -> b.specificity - a.specificity
      _.defaults(keystrokeMap, set.commandsByKeystrokes) for set in bindingSets
      currentNode = currentNode.parent()

    keystrokeMap

  handleKeyEvent: (event) ->
    event.keystrokes = @multiKeystrokeStringForEvent(event)
    isMultiKeystroke = @queuedKeystrokes?
    @queuedKeystrokes = null
    currentNode = $(event.target)
    while currentNode.length
      candidateBindingSets = @bindingSets.filter (set) -> currentNode.is(set.selector)
      candidateBindingSets.sort (a, b) -> b.specificity - a.specificity
      for bindingSet in candidateBindingSets
        command = bindingSet.commandForEvent(event)
        if command
          continue if @triggerCommandEvent(event, command)
          return false
        else if command == false
          return false

        if bindingSet.matchesKeystrokePrefix(event)
          @queuedKeystrokes = event.keystrokes
          return false
      currentNode = currentNode.parent()

    !isMultiKeystroke

  triggerCommandEvent: (keyEvent, commandName) ->
    commandEvent = $.Event(commandName)
    commandEvent.keyEvent = keyEvent
    aborted = false
    commandEvent.abortKeyBinding = ->
      @stopImmediatePropagation()
      aborted = true
    $(keyEvent.target).trigger(commandEvent)
    aborted

  multiKeystrokeStringForEvent: (event) ->
    currentKeystroke = @keystrokeStringForEvent(event)
    if @queuedKeystrokes
      @queuedKeystrokes + ' ' + currentKeystroke
    else
      currentKeystroke

  keystrokeStringForEvent: (event) ->
    if /^U\+/i.test event.originalEvent.keyIdentifier
      hexCharCode = event.originalEvent.keyIdentifier.replace(/^U\+/i, '')
      charCode = parseInt(hexCharCode, 16)
      key = @keyFromCharCode(charCode)
    else
      key = event.originalEvent.keyIdentifier.toLowerCase()

    modifiers = ''
    if event.altKey and key isnt 'alt'
      modifiers += 'alt-'
    if event.ctrlKey and key isnt 'ctrl'
      modifiers += 'ctrl-'
    if event.metaKey and key isnt 'meta'
      modifiers += 'meta-'

    if event.shiftKey
      isNamedKey = key.length > 1
      modifiers += 'shift-' if isNamedKey
    else
      key = key.toLowerCase()

    "#{modifiers}#{key}"

  keyFromCharCode: (charCode) ->
    switch charCode
      when 8 then 'backspace'
      when 9 then 'tab'
      when 13 then 'enter'
      when 27 then 'escape'
      when 32 then 'space'
      when 127 then 'delete'
      else String.fromCharCode(charCode)
