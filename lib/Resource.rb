#!/usr/bin/env ruby -w
# encoding: UTF-8
#
# = Resource.rb -- The TaskJuggler III Project Management Software
#
# Copyright (c) 2006, 2007, 2008, 2009, 2010 by Chris Schlaeger <cs@kde.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#


require 'PropertyTreeNode'
require 'ResourceScenario'

class TaskJuggler

  class Resource < PropertyTreeNode

    def initialize(project, id, name, parent)
      super(project.resources, id, name, parent)
      project.addResource(self)

      @data = Array.new(@project.scenarioCount, nil)
      @project.scenarioCount.times do |i|
        @data[i] = ResourceScenario.new(self, i, @scenarioAttributes[i])
      end
    end

    # Many Resource functions are scenario specific. These functions are
    # provided by the class ResourceScenario. In case we can't find a
    # function called for the Resource class we try to find it in
    # ResourceScenario.
    def method_missing(func, scenarioIdx, *args)
      @data[scenarioIdx].method(func).call(*args)
    end

    def query_journal(query)
      journalMessages(query, true)
    end

    private

    # Create a blog-style list of all alert messages that match the Query.
    def journalMessages(query, longVersion)
      # The components of the message are either UTF-8 text or RichText. For
      # the RichText components, we use the originally provided markup since
      # we compose the result as RichText markup first.
      rText = ''
      list = @project['journal'].entriesByResource(self, query.start, query.end)
      # Sort all entries in buckets by their alert level.
      numberOfLevels = project['alertLevels'].length
      listByLevel = []
      0.upto(numberOfLevels - 1) { |i| listByLevel[i] = [] }
      list.each do |entry|
        listByLevel[entry.alertLevel] << entry
      end
      first = true
      (numberOfLevels - 1).downto(0) do |level|
        levelList = listByLevel[level]
        alertName = @project['alertLevels'][level][1]
        rText += "== #{alertName}: ==\n\n"
        if levelList.empty?
          rText += "./.\n\n"
        else
          levelList.each do |entry|
            # Separate the messages with a horizontal line.
            if first
              first = false
            else
              rText += "----\n"
            end
            if entry.property.is_a?(Task)
              rText += "=== Task #{entry.property.name} "+
                "(ID: #{entry.property.fullId}) ===\n\n"
            end
            rText += entry.headline + "\n\n"
            if entry.summary
              rText += entry.summary.richText.inputText + "\n\n"
            end
            if longVersion && entry.details
              rText += entry.details.richText.inputText + "\n\n"
            end
          end
        end
      end

      # Now convert the RichText markup String into RichTextIntermediate
      # format.
      handlers = [
        RTFNavigator.new(@project),
        RTFQuery.new(@project),
        RTFReport.new(@project)
      ]
      begin
        rti = RichText.new(rText, handlers).generateIntermediateFormat
      rescue RichTextException => msg
        $stderr.puts "Error while processing Rich Text\n" +
                     "Line #{msg.lineNo}: #{msg.text}\n" +
                     "#{msg.line}"
        return nil
      end
      # No section numbers, please!
      # rti.sectionNumbers = false
      # We use a special class to allow CSS formating.
      rti.cssClass = 'alertmessage'
      query.rti = rti
    end
  end

end

