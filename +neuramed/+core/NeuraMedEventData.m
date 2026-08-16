classdef NeuraMedEventData < event.EventData
    % NEURAMEDEVENTDATA Generic payload wrapper for toolkit-wide events.
    properties
        Payload
        Timestamp datetime
    end
    methods
        function obj = NeuraMedEventData(payload)
            obj.Payload = payload;
            obj.Timestamp = datetime('now');
        end
    end
end
