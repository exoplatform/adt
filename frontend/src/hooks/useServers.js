import { useQuery } from '@tanstack/react-query';

export const useServers = () => {
  return useQuery({
    queryKey: ['servers'],
    queryFn: async () => {
      const response = await fetch('/rest/servers.php');
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      return response.json();
    },
  });
};
