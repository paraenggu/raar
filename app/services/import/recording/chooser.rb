module Import
  module Recording
    # Compares an array of audio files and returns the best one.
    class Chooser

      attr_reader :variants

      def initialize(variants)
        @variants = variants
      end

      def best
        by_audio_length.first
      end

      def by_audio_length
        # using with_index and a sort_by array results in a stable sort,
        # i.e. positions remain the same if the duration is equal.
        variants.sort_by.with_index do |v, i|
          duration = v.audio_duration > v.duration ? v.duration : v.audio_duration
          [-duration, i]
        end
      end

    end
  end
end
