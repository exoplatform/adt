import { useQuery } from '@tanstack/react-query';

export const useFeatures = () => {
  return useQuery({
    queryKey: ['features'],
    queryFn: async () => {
      const response = await fetch('/rest/features.php');
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      return response.json();
    },
  });
};
