import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import { io } from 'socket.io-client';

export const useWebSockets = () => {
  const queryClient = useQueryClient();

  useEffect(() => {
    const socket = io({
      path: '/ws'
    });

    socket.on('data-updated', (data) => {
      console.log('Data updated event received:', data);
      // Invalidate all instance queries to trigger refetch
      queryClient.invalidateQueries({ queryKey: ['instances'] });
      queryClient.invalidateQueries({ queryKey: ['features'] });
      queryClient.invalidateQueries({ queryKey: ['servers'] });
    });

    return () => {
      socket.disconnect();
    };
  }, [queryClient]);
};
