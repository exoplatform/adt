import { useQuery } from '@tanstack/react-query';

export const useInstances = (type = 'acceptance') => {
  return useQuery({
    queryKey: ['instances', type],
    queryFn: async () => {
      const response = await fetch(`/rest/instances.php?type=${type}`);
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      return response.json();
    },
  });
};
