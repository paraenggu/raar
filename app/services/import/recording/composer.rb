module Import
  module Recording

    # From a list of recordings, split or join them to correspond to a single broadcast.
    # The recordings must overlap or correspond to the broadcast duration but must not be shorter.
    #
    # If the audio duration of the given recordings is longer than declared, the files are trimmed
    # at the end. If the audio duration is shorter, the recordings are used from the declared
    # start position as long as available.
    #
    # In the case that recordings overlap each other, they are trimmed to build an adjacent stream.
    class Composer

      attr_reader :mapping, :recordings

      def initialize(mapping, recordings)
        @mapping = mapping
        @recordings = recordings.sort_by(&:started_at)
        check_arguments
      end

      # Compose the recordings and return the resulting file.
      def compose
        if first_equal?
          file_with_maximum_duration(first)
        elsif first_earlier_and_longer?
          trim_start_and_end
        else
          concat_list
        end
      end

      private

      def check_arguments
        raise(ArgumentError, 'broadcast mapping must be complete') unless mapping.complete?
        if (recordings - mapping.recordings).present?
          raise(ArgumentError, 'recordings must be part of the broadcast mapping')
        end
      end

      def first
        recordings.first
      end

      def last
        recordings.last
      end

      def first_equal?
        first.started_at == mapping.started_at &&
          first.finished_at == mapping.finished_at
      end

      def first_earlier_and_longer?
        first.started_at <= mapping.started_at &&
          first.finished_at >= mapping.finished_at
      end

      def first_earlier?
        first.started_at < mapping.started_at
      end

      def last_longer?(current)
        current == last && current.finished_at > mapping.finished_at
      end

      def trim_start_and_end
        start = mapping.started_at - first.started_at
        duration = mapping.duration
        trim_available(first, start, duration)
      end

      def concat_list
        list = []
        @previous_finished_at = mapping.started_at
        recordings.each_with_index do |r, i|
          list << trim_list_recording(r, i)
        end

        concat(list.compact)
      ensure
        list.each { |file| file.close! if file.respond_to?(:close!) }
      end

      def trim_list_recording(current, i)
        if previous_overlapping_current?(current)
          trim_overlapped(current) if previous_not_overlapping_next?(current, i)
        elsif last_longer?(current)
          trim_end
        else
          trim_to_maximum_duration(current)
        end
      end

      def previous_overlapping_current?(current)
        @previous_finished_at > current.started_at + DURATION_TOLERANCE
      end

      def previous_not_overlapping_next?(current, i)
        @next_started_at = next_started_at(current, i)
        @previous_finished_at < @next_started_at - DURATION_TOLERANCE
      end

      def next_started_at(current, i)
        current == last ? mapping.finished_at : recordings[i + 1].started_at
      end

      def trim_overlapped(current)
        start = @previous_finished_at - current.started_at
        duration = @next_started_at - @previous_finished_at
        @previous_finished_at += [duration, current.audio_duration - start].min.seconds
        trim_available(current, start, duration)
      end

      def trim_to_maximum_duration(current)
        @previous_finished_at = current.started_at +
                                [current.duration, current.audio_duration].min.seconds
        file_with_maximum_duration(current)
      end

      def trim_end
        duration = mapping.finished_at - last.started_at
        trim_available(last, 0, duration)
      end

      def file_with_maximum_duration(recording)
        if recording.audio_duration_too_long?
          trim_available(recording, 0, recording.duration)
        else
          recording
        end
      end

      def trim_available(recording, start, duration)
        if start < recording.audio_duration
          duration = [duration, recording.audio_duration - start].min
          trim(recording.path, start, duration)
        end
      end

      def trim(file, start, duration)
        new_tempfile(file).tap do |target_file|
          proc = AudioProcessor.new(file)
          proc.trim(target_file.path, start, duration)
        end
      end

      def concat(list)
        return list.first if list.size <= 1

        with_same_format(list) do |unified|
          new_tempfile(unified[0]).tap do |target_file|
            proc = AudioProcessor.new(unified[0])
            proc.concat(target_file.path, unified[1..-1])
          end
        end
      end

      def with_same_format(list)
        unified = convert_all_to_same_format(list)
        yield unified.collect(&:path)
      ensure
        unified && unified.each { |file| file.close! if file.respond_to?(:close!) }
      end

      def convert_all_to_same_format(list)
        format = AudioProcessor.new(list.first.path).audio_format
        list.map do |file|
          # always convert flacs to assert a common frame size
          if ::File.extname(file.path) != ".#{format.file_extension}" || format.codec == 'flac'
            convert_to_format(file, format)
          else
            file
          end
        end
      end

      def convert_to_format(file, format)
        Tempfile.new(['master', ".#{format.file_extension}"]).tap do |target_file|
          proc = AudioProcessor.new(file.path)
          proc.transcode(target_file.path, format)
        end
      end

      def new_tempfile(template = first.path)
        Tempfile.new(['master', ::File.extname(template)])
      end

    end

  end
end
